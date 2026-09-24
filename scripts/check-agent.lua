local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/bin", "p")
local original_path = vim.env.PATH
local file = root .. "/context with spaces.txt"
local live = vim.env.AGENT_LIVE == "1"
local passed = {}
local history_start = 0
local ns = vim.api.nvim_create_namespace "lean_vim_agent"

local function check(ok, message)
  assert(ok, message)
end

local function notifications()
  return require("mini.notify").get_all()
end

local function status()
  return vim.api.nvim_eval_statusline(vim.o.statusline, { winid = vim.api.nvim_get_current_win() }).str
end

local function working()
  return status():find("Working", 1, true) ~= nil
end

local function saw(message, level)
  return vim.wait(1000, function()
    for id, notification in pairs(notifications()) do
      if
        id > history_start
        and notification.msg:find(message, 1, true)
        and (not level or notification.level == level)
      then
        return true
      end
    end
    return false
  end, 10)
end

local function type_command(command)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(":" .. command .. "<CR>", true, false, true), "xt", false)
end

local function finish()
  check(
    vim.wait(live and 180000 or 10000, function()
      return not working()
    end, 20),
    "agent did not finish"
  )
end

local function reset(scenario)
  require("mini.notify").clear()
  history_start = #notifications()
  vim.env.AGENT_SCENARIO = scenario
  vim.fn.writefile({ "The current token is TANGERINE." }, file)
  vim.cmd.edit { args = { file }, bang = true }
end

local function scenario(name, run)
  run()
  passed[#passed + 1] = name
  print("PASS " .. name)
end

local ok, err = xpcall(function()
  check(vim.fn.exists ":Agent" == 2, ":Agent is not registered")
  vim.o.columns = 200
  check(status():find("Normal", 1, true), "statusline does not show the mode when idle")
  if not live then
    vim.fn.writefile(
      vim.split(
        [=[#!/usr/bin/env python3
import json, os, pathlib, sys, time
args = sys.argv[1:]
prompt = sys.stdin.read()
root = pathlib.Path(os.environ["AGENT_TEST_ROOT"])
(root / "call.json").write_text(json.dumps({"args": args, "prompt": prompt, "cwd": os.getcwd()}))
scenario = os.environ.get("AGENT_SCENARIO", "answer")
target = root / "context with spaces.txt"

def emit(event):
    print(json.dumps(event), flush=True)

def update(kind, **fields):
    emit({"type": "message_update", "assistantMessageEvent": {"type": kind, "contentIndex": 0, **fields}})

def reply(text, stop="stop", error=None):
    emit({"type": "message_start"})
    update("text_start")
    content = [{"type": "text", "text": text}] if text else []
    emit({"type": "message_end", "message": {"role": "assistant", "content": content, "stopReason": stop, "errorMessage": error}})

time.sleep(30 if scenario == "cancel" else 1)
if scenario == "crash":
    print("Synthetic crash", file=sys.stderr)
    sys.exit(7)
if scenario == "error":
    reply("", "error", "Synthetic authentication failure")
    sys.exit(0)
if scenario in ("edit", "conflict", "typing", "cancel_stream"):
    arguments = {"path": target.name, "edits": [{"oldText": "TANGERINE", "newText": "PAPAYA"}]}
    raw = json.dumps(arguments)
    emit({"type": "message_start"})
    update("toolcall_start", id="call_1", toolName="edit")
    for i in range(0, len(raw), 2):
        update("toolcall_delta", delta=raw[i : i + 2])
        time.sleep(0.05)
        if scenario == "cancel_stream" and i > len(raw) - 8:
            time.sleep(30)
    update("toolcall_end", toolCall={"type": "toolCall", "id": "call_1", "name": "edit", "arguments": arguments})
    emit({"type": "message_end", "message": {"role": "assistant", "content": [], "stopReason": "toolUse"}})
    emit({"type": "tool_execution_start", "toolCallId": "call_1", "toolName": "edit", "args": arguments})
    target.write_text(target.read_text().replace("TANGERINE", "PAPAYA"))
    time.sleep(0.5)
    emit({"type": "tool_execution_end", "toolCallId": "call_1", "toolName": "edit", "isError": False})
    reply("Changed token to PAPAYA.")
elif scenario != "empty":
    emit({"type": "message_start"})
    update("thinking_start")
    reply("The token is TANGERINE.")
]=],
        "\n"
      ),
      root .. "/bin/pi"
    )
    vim.fn.setfperm(root .. "/bin/pi", "rwx------")
    vim.env.AGENT_TEST_ROOT = root
    vim.env.PATH = root .. "/bin:" .. original_path
  end

  scenario("lowercase command, current file context, statusline spinner, answer toast", function()
    reset "answer"
    local before = vim.fn.readfile(file)
    type_command "agent What is the current token? Reply in one sentence and do not edit any files."
    check(working(), "statusline did not switch to Working immediately")
    vim.o.columns = 80
    check(status():find("Working  ", 1, true), "narrow statusline did not drop the step detail")
    vim.o.columns = 200
    check(not status():find("Normal", 1, true), "mode still shown while working")
    for _, notification in pairs(notifications()) do
      check(notification.ts_remove, "a toast is shown while working: " .. notification.msg)
    end
    local responsive = false
    vim.defer_fn(function()
      responsive = true
    end, 20)
    check(
      vim.wait(500, function()
        return responsive
      end, 10),
      "Neovim blocked during the request"
    )
    finish()
    check(saw "TANGERINE", "missing answer notification")
    check(
      vim.iter(notifications()):any(function(n)
        return not n.ts_remove and n.msg:find("TANGERINE", 1, true)
      end),
      "answer was not shown as a toast"
    )
    check(vim.deep_equal(vim.fn.readfile(file), before), "question changed the file")
    if not live then
      local call = vim.json.decode(table.concat(vim.fn.readfile(root .. "/call.json"), "\n"))
      check(vim.tbl_contains(call.args, "fireworks/accounts/fireworks/models/deepseek-v4p1-flash"), "wrong model")
      check(vim.tbl_contains(call.args, "--no-session"), "run was persisted as a pi session")
      check(vim.tbl_contains(call.args, "json"), "events are not streamed as JSON")
      check(call.prompt:find(file, 1, true), "missing current filename")
      check(call.prompt:find("The current token is TANGERINE.", 1, true), "missing buffer content")
      check(call.cwd == root, "wrong directory for a file outside Git")
    end
  end)

  scenario("unsaved content is saved, edit streams into the buffer, then lands as one undo step", function()
    reset "edit"
    vim.api.nvim_buf_set_lines(0, 1, 1, false, { "Preserve this unsaved line." })
    type_command "agent Change only TANGERINE to PAPAYA in the current file. Preserve every other line and edit the file now."
    check(not vim.bo.modified, "current buffer was not saved")
    if not live then
      local states = {}
      vim.wait(5000, function()
        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
        if line ~= states[#states] and vim.fn.readfile(file)[1]:find("TANGERINE", 1, true) then
          states[#states + 1] = line
        end
        return line == "The current token is PAPAYA."
      end, 10)
      check(#states >= 3, "edit was not streamed progressively: " .. vim.inspect(states))
      check(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 0, "streamed text is not highlighted")
      check(status():find("writing context with spaces.txt:1", 1, true), "spinner does not say where it is writing")
      check(
        vim.wait(3000, function()
          return vim.fn.readfile(file)[1] == "The current token is PAPAYA."
        end, 10),
        "fixture never wrote the edit"
      )
      vim.cmd "checktime"
      check(working(), "checktime during the preview interrupted the run")
    end
    finish()
    check(not vim.bo.modified, "buffer is left modified")
    check(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) == 0, "preview highlight was left behind")
    check(vim.fn.readfile(file)[1] == "The current token is PAPAYA.", "file was not edited")
    check(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "The current token is PAPAYA.", "buffer did not reload")
    check(vim.fn.readfile(file)[2] == "Preserve this unsaved line.", "unsaved content was lost")
    check(saw "PAPAYA", "edit summary missing from notification history")
    for id, notification in pairs(notifications()) do
      check(id <= history_start or notification.ts_remove, "a toast was shown after the edit: " .. notification.msg)
    end
    vim.cmd "silent undo"
    check(
      vim.deep_equal(
        vim.api.nvim_buf_get_lines(0, 0, -1, false),
        { "The current token is TANGERINE.", "Preserve this unsaved line." }
      ),
      "one undo does not restore the pre-agent text"
    )
  end)

  if live then
    return
  end

  scenario("literal prompt punctuation and duplicate-run guard", function()
    reset "answer"
    local prompt = [[Explain agent | echo 'no' $(touch /tmp/agent-should-not-exist) `no` % #]]
    type_command("agent " .. prompt)
    type_command "agent duplicate"
    check(saw("already working", "WARN"), "duplicate was not rejected")
    finish()
    local call = vim.json.decode(table.concat(vim.fn.readfile(root .. "/call.json"), "\n"))
    check(call.prompt:find(prompt, 1, true), "prompt was expanded or executed")
  end)

  scenario("edits made while the agent runs survive", function()
    reset "conflict"
    type_command "agent Change the token"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "My concurrent edit." })
    finish()
    check(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "My concurrent edit.", "concurrent edit was overwritten")
    check(vim.bo.modified, "concurrent edit lost its modified flag")
    check(saw("unsaved", "WARN"), "missing conflict notification")
  end)

  scenario("typing during the live preview keeps the typed text", function()
    reset "typing"
    type_command "agent Change the token"
    check(
      vim.wait(5000, function()
        return vim.bo.modified
      end, 10),
      "preview never started"
    )
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "My typing during the preview." })
    finish()
    check(
      vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "My typing during the preview." }),
      "typed text was overwritten"
    )
    check(saw("unsaved", "WARN"), "missing conflict notification")
  end)

  scenario("cancelling mid-stream restores the buffer", function()
    reset "cancel_stream"
    type_command "agent Change the token"
    check(
      vim.wait(5000, function()
        return vim.bo.modified
      end, 10),
      "preview never started"
    )
    type_command "AgentCancel"
    finish()
    check(
      vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "The current token is TANGERINE." }),
      "partial preview was left in the buffer"
    )
    check(not vim.bo.modified, "buffer is left modified after cancel")
    check(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) == 0, "preview highlight was left after cancel")
  end)

  scenario("CLI crashes and model errors clear loading and report the cause", function()
    reset "crash"
    type_command "agent Explain this file"
    finish()
    check(saw("Synthetic crash", "ERROR"), "missing CLI failure")
    reset "error"
    type_command "agent Explain this file"
    finish()
    check(saw("Synthetic authentication failure", "ERROR"), "model error exited 0 but was not reported")
  end)

  scenario("empty responses are reported", function()
    reset "empty"
    type_command "agent Explain this file"
    finish()
    check(saw("no final message", "WARN"), "empty response was silently accepted")
  end)

  scenario("cancellation clears loading and permits another request", function()
    reset "cancel"
    type_command "agent Explain this file"
    check(working(), "cancel scenario did not start")
    type_command "AgentCancel"
    finish()
    check(saw("cancelled", "WARN"), "missing cancellation notification")
    reset "answer"
    type_command "agent Explain this file"
    finish()
  end)

  scenario("unnamed and read-only buffers are rejected before starting", function()
    vim.cmd.enew { bang = true }
    type_command "agent Explain this"
    check(not working(), "unnamed buffer started a process")
    check(saw("named", "WARN"), "missing unnamed-buffer notification")
    reset "answer"
    vim.bo.readonly = true
    type_command "agent Edit this"
    check(not working(), "read-only buffer started a process")
    check(saw("read-only", "WARN"), "missing read-only notification")
    vim.bo.readonly = false
  end)

  scenario("missing pi is reported without leaving a spinner", function()
    vim.env.PATH = root .. "/missing"
    type_command "agent Explain this"
    check(not working(), "missing binary left a spinner")
    check(saw("pi is not on PATH", "ERROR"), "missing executable was not reported")
  end)
end, debug.traceback)

vim.env.PATH = original_path
vim.cmd "silent! AgentCancel"
vim.fn.delete(root, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd "cquit 1"
else
  print(
    ("Agent E2E: %d scenarios passed (%s). Repeat: %smake check-agent"):format(
      #passed,
      live and "live pi" or "CLI fixture",
      live and "AGENT_LIVE=1 " or ""
    )
  )
  vim.cmd "qa!"
end
