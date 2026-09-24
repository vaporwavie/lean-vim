local M = {}
local active
local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local ns = vim.api.nvim_create_namespace "lean_vim_agent"
local model = "fireworks/accounts/fireworks/models/deepseek-v4p1-flash"

local function disk_version(path)
  local stat = vim.uv.fs_stat(path)
  return stat and ("%s:%s:%s"):format(stat.size, stat.mtime.sec, stat.mtime.nsec) or "missing"
end

-- Returns the JSON prefix closed off, plus the key whose string value is still streaming.
local function close_json(raw)
  local closers, in_string, escaped, is_key, key, prev, start = {}, false, false, false, nil, nil, nil
  for i = 1, #raw do
    local c = raw:byte(i)
    if in_string then
      if escaped then
        escaped = false
      elseif c == 92 then
        escaped = true
      elseif c == 34 then
        in_string, prev = false, 34
        if is_key then
          key = raw:sub(start + 1, i - 1)
        end
      end
    elseif c == 34 then
      in_string, start = true, i
      is_key = closers[#closers] == "}" and (prev == 123 or prev == 44)
    elseif c == 123 or c == 91 then
      closers[#closers + 1], prev = c == 123 and "}" or "]", c
    elseif c == 125 or c == 93 then
      closers[#closers], prev = nil, c
    elseif c ~= 32 and c ~= 9 and c ~= 10 and c ~= 13 then
      prev = c
    end
  end
  local text, streaming = raw, nil
  if in_string then
    if is_key then
      return
    end
    text = (escaped and text:sub(1, -2) or text):gsub("\\u%x*$", "") .. '"'
    streaming = key
  else
    text = text:gsub("[%s,]*$", "")
    if text:sub(-1) == ":" then
      return
    end
  end
  for i = #closers, 1, -1 do
    text = text .. closers[i]
  end
  return text, streaming
end

local function find_buf(path, cwd)
  if type(path) ~= "string" or path == "" then
    return
  end
  path = vim.fs.normalize(path)
  if path:sub(1, 1) ~= "/" then
    path = vim.fs.normalize(vim.fs.joinpath(cwd, path))
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == ""
      and vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) == path
    then
      return buf
    end
  end
end

local function position(text, offset)
  local before = text:sub(1, offset)
  local _, row = before:gsub("\n", "")
  local newline = before:match ".*()\n"
  return row, newline and offset - newline or offset
end

local function render(run, call)
  local args = call.args
  call.buf = call.buf or find_buf(args.path, run.cwd)
  local buf = call.buf
  if not buf or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  local preview = run.previews[buf]
  if not preview then
    if vim.bo[buf].modified then
      return
    end
    preview = {
      owner = call,
      seq = vim.fn.undotree(buf).seq_cur,
      tick = vim.b[buf].changedtick,
      base = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"),
    }
    run.previews[buf] = preview
    -- Disk changes mid-preview would otherwise raise the blocking W12 prompt.
    vim.api.nvim_create_autocmd("FileChangedShell", {
      group = run.group,
      buffer = buf,
      callback = function()
        vim.v.fcs_choice = ""
      end,
    })
  end
  if preview.owner ~= call or preview.abandoned then
    return
  end
  if preview.tick ~= vim.b[buf].changedtick then
    preview.abandoned = true
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    return
  end

  local text, spans = preview.base, {}
  if call.name == "write" then
    if type(args.content) ~= "string" then
      return
    end
    text = args.content:gsub("\n$", "")
    spans[1] = { 0, #text }
  else
    local edits = type(args.edits) == "table" and args.edits or { args }
    for i, edit in ipairs(edits) do
      local old, new = edit.oldText, edit.newText
      if
        type(old) == "string"
        and old ~= ""
        and type(new) == "string"
        and not (i == #edits and call.streaming == "oldText")
      then
        local at = text:find(old, 1, true)
        if at then
          text = text:sub(1, at - 1) .. new .. text:sub(at + #old)
          for _, span in ipairs(spans) do
            if span[1] >= at - 1 then
              span[1], span[2] = span[1] + #new - #old, span[2] + #new - #old
            end
          end
          spans[#spans + 1] = { at - 1, at - 1 + #new }
        end
      end
    end
  end
  if #spans == 0 then
    return
  end

  local lines = vim.split(text, "\n", { plain = true })
  local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local first, last_new, last_old = 1, #lines, #current
  while first <= last_new and first <= last_old and lines[first] == current[first] do
    first = first + 1
  end
  while last_new >= first and last_old >= first and lines[last_new] == current[last_old] do
    last_new, last_old = last_new - 1, last_old - 1
  end
  if first <= last_new or first <= last_old then
    vim.api.nvim_buf_call(buf, function()
      if preview.written then
        pcall(vim.cmd, "undojoin")
      end
      vim.api.nvim_buf_set_lines(buf, first - 1, last_old, false, vim.list_slice(lines, first, last_new))
    end)
    preview.written, preview.tick = true, vim.b[buf].changedtick
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local row, col
  for _, span in ipairs(spans) do
    local start_row, start_col = position(text, span[1])
    row, col = position(text, span[2])
    vim.api.nvim_buf_set_extmark(buf, ns, start_row, start_col, {
      end_row = row,
      end_col = col,
      hl_group = "AgentStream",
      strict = false,
    })
  end
  if call.streaming then
    vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
      virt_text = { { "▍", "AgentStream" } },
      virt_text_pos = "inline",
      strict = false,
    })
  end
  run.status = ("writing %s:%d"):format(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t"), row + 1)
end

local function settle(run, buf)
  local preview = run.previews[buf]
  run.previews[buf] = nil
  vim.api.nvim_clear_autocmds { group = run.group, buffer = buf }
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if preview.abandoned or preview.tick ~= vim.b[buf].changedtick then
    return
  end
  vim.api.nvim_buf_call(buf, function()
    if preview.written then
      pcall(vim.cmd, "silent undo " .. preview.seq)
    end
    pcall(vim.cmd, "silent edit!")
  end)
end

local function track(run, call)
  local args = call.args
  if call.streaming == "path" then
    run.status = call.name
  elseif call.name == "edit" or call.name == "write" then
    run.status = "writing " .. vim.fn.fnamemodify(tostring(args.path or ""), ":t")
    render(run, call)
  elseif call.name == "bash" and type(args.command) == "string" then
    run.status = "running " .. args.command:gsub("%s+", " "):sub(1, 40)
  elseif call.name == "read" and type(args.path) == "string" then
    run.status = "reading " .. vim.fn.fnamemodify(args.path, ":t")
  end
end

local function handle(run, event)
  local update = event.assistantMessageEvent
  if event.type == "message_start" then
    run.calls = {}
  elseif update then
    local call = run.calls[update.contentIndex]
    if update.type == "thinking_start" then
      run.status = "thinking"
    elseif update.type == "text_start" then
      run.status = "answering"
    elseif update.type == "toolcall_start" then
      call = { name = update.toolName, raw = "" }
      run.calls[update.contentIndex], run.by_id[update.id], run.status = call, call, update.toolName
    elseif call and update.type == "toolcall_delta" then
      call.raw = call.raw .. update.delta
      local text, streaming = close_json(call.raw)
      local ok, args = pcall(vim.json.decode, text or "", { luanil = { object = true, array = true } })
      if ok and type(args) == "table" then
        call.args, call.streaming = args, streaming
        track(run, call)
      end
    elseif call and update.type == "toolcall_end" and type(vim.tbl_get(update, "toolCall", "arguments")) == "table" then
      call.args, call.streaming = update.toolCall.arguments, nil
      track(run, call)
    end
  elseif event.type == "tool_execution_end" then
    local call = run.by_id[event.toolCallId]
    if call and (call.name == "edit" or call.name == "write") and not event.isError then
      run.edited = true
    end
    if call and call.buf and vim.api.nvim_buf_is_loaded(call.buf) then
      local preview = run.previews[call.buf]
      if preview and preview.owner == call then
        settle(run, call.buf)
      elseif not vim.bo[call.buf].modified then
        pcall(vim.cmd, "silent checktime " .. call.buf)
      end
    end
  elseif event.type == "message_end" and event.message.role == "assistant" then
    local parts = {}
    for _, part in ipairs(event.message.content or {}) do
      if part.type == "text" then
        parts[#parts + 1] = part.text
      end
    end
    run.message = vim.trim(table.concat(parts, "\n"))
    run.error = event.message.stopReason == "error" and (event.message.errorMessage or "unknown error") or nil
  end
end

local function refresh_buffers(run)
  local conflicts = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
      local path = vim.api.nvim_buf_get_name(buf)
      if vim.bo[buf].modified then
        if run.versions[path] and run.versions[path] ~= disk_version(path) then
          conflicts[#conflicts + 1] = vim.fn.fnamemodify(path, ":~:.")
        end
      else
        pcall(vim.cmd, "silent checktime " .. buf)
      end
    end
  end
  if #conflicts > 0 then
    vim.notify(
      "Agent: unsaved edits kept in " .. table.concat(conflicts, ", ") .. ". Compare with disk before saving.",
      vim.log.levels.WARN
    )
  end
end

local function finish(run, result)
  if active ~= run then
    return
  end
  active = nil
  run.timer:stop()
  run.timer:close()
  vim.cmd "redrawstatus"
  for buf in pairs(run.previews) do
    settle(run, buf)
  end
  vim.api.nvim_del_augroup_by_id(run.group)
  refresh_buffers(run)

  if run.cancelled then
    vim.notify("Agent cancelled; any completed edits remain on disk.", vim.log.levels.WARN)
  elseif result.code ~= 0 then
    local detail = vim.trim(result.stderr or ""):sub(-2000)
    local reason = result.code == 124 and "timed out after 10 minutes" or "failed (exit " .. result.code .. ")"
    vim.notify("Agent " .. reason .. (detail ~= "" and ":\n" .. detail or ""), vim.log.levels.ERROR)
  elseif run.error then
    vim.notify("Agent failed: " .. run.error, vim.log.levels.ERROR)
  elseif run.edited then
    local notify = require "mini.notify"
    notify.remove(notify.add("Agent: " .. (run.message ~= "" and run.message or "edits applied.")))
  elseif run.message == "" then
    vim.notify("Agent finished with no final message.", vim.log.levels.WARN)
  else
    vim.notify("Agent: " .. run.message)
  end
end

local function start(opts)
  if active then
    vim.notify("Agent is already working. Use :AgentCancel to stop it.", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable "pi" ~= 1 then
    vim.notify("Agent: pi is not on PATH.", vim.log.levels.ERROR)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or vim.bo[buf].buftype ~= "" then
    vim.notify("Agent needs a named file buffer. Save it with :write first.", vim.log.levels.WARN)
    return
  end
  if vim.bo[buf].readonly or not vim.bo[buf].modifiable then
    vim.notify("Agent cannot edit a read-only buffer.", vim.log.levels.WARN)
    return
  end
  local saved, err = pcall(function()
    if vim.bo[buf].modified or vim.fn.filereadable(path) == 0 then
      vim.cmd "silent write"
    end
  end)
  if not saved then
    vim.notify("Agent could not save the current buffer: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_set_hl(0, "AgentStream", { default = true, link = "DiffAdd" })
  local run = {
    cwd = vim.fs.root(path, ".git") or vim.fs.dirname(path),
    timer = vim.uv.new_timer(),
    versions = {},
    calls = {},
    by_id = {},
    previews = {},
    message = "",
    status = "starting",
    frame = 1,
    group = vim.api.nvim_create_augroup("LeanVimAgentPreview", { clear = true }),
  }
  local unsaved = {}
  for _, other in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(other) and vim.bo[other].buftype == "" then
      local name = vim.api.nvim_buf_get_name(other)
      run.versions[name] = disk_version(name)
      if vim.bo[other].modified then
        unsaved[#unsaved + 1] = name
      end
    end
  end
  local prompt = table.concat({
    "You are helping inside Neovim. The JSON below contains the user's request and current file context.",
    "For an edit request, make the requested changes directly in the workspace now. For a question, answer without changing files.",
    "The current file's full content is in the JSON, so do not read it again. Change existing files with the edit tool.",
    "Keep changes scoped to the request, preserve unrelated changes, and do not commit or push.",
    "Do not edit files listed in unsaved_buffers: they have other unsaved work in the editor.",
    "Finish with a concise plain-text message for a toast notification, ideally 1-3 sentences.",
    vim.json.encode {
      request = opts.args,
      file = {
        path = path,
        filetype = vim.bo[buf].filetype,
        content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"),
      },
      unsaved_buffers = unsaved,
    },
  }, "\n\n")
  active = run
  vim.cmd "redrawstatus"
  run.timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      if active == run then
        run.frame = run.frame % #frames + 1
        vim.cmd "redrawstatus"
      end
    end)
  )

  local pending = ""
  local function on_stdout(_, data)
    pending = pending .. (data or "\n")
    local lines = {}
    for line in pending:gmatch "([^\n]*)\n" do
      lines[#lines + 1] = line
    end
    pending = pending:match "[^\n]*$"
    if #lines > 0 then
      vim.schedule(function()
        for _, line in ipairs(lines) do
          local ok, event = pcall(vim.json.decode, line, { luanil = { object = true, array = true } })
          if active == run and ok and type(event) == "table" then
            handle(run, event)
          end
        end
      end)
    end
  end

  local started, process = pcall(
    vim.system,
    { "pi", "--mode", "json", "--no-session", "--model", model, "--thinking", "low" },
    { cwd = run.cwd, stdin = prompt, text = true, stdout = on_stdout, timeout = 600000 },
    vim.schedule_wrap(function(result)
      finish(run, result)
    end)
  )
  if started then
    run.process = process
  else
    finish(run, { code = 1, stderr = tostring(process) })
  end
end

function M.status(short)
  if active then
    local spinner = frames[active.frame] .. " Working"
    return short and spinner or spinner .. " · " .. active.status
  end
end

vim.api.nvim_create_user_command("Agent", start, { nargs = "+", desc = "Ask pi about or edit the current file" })
vim.keymap.set("ca", "agent", function()
  return vim.fn.getcmdtype() == ":" and vim.fn.getcmdline():match "^%s*agent$" and "Agent" or "agent"
end, { expr = true })
vim.api.nvim_create_user_command("AgentCancel", function()
  if active and active.process then
    active.cancelled = true
    active.process:kill(15)
  end
end, { desc = "Cancel the current pi request" })
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("LeanVimAgent", { clear = true }),
  callback = function()
    if active and active.process then
      active.process:kill(15)
    end
  end,
})

return M
