-- Start screen: a dithered Doric column bleeding through a rounded panel that
-- holds the action legend. The column art is the ASCII preview emitted by the
-- landing site's scripts/generate-pillar.mjs (8x8 Bayer-dithered Greek column),
-- trimmed to a compact shaft. Drawn by hand (not mini.starter) so the column
-- can overlap the panel and carry its own dim tone.
local do_now = MiniDeps.now

do_now(function()
  local ns = vim.api.nvim_create_namespace "altura_start"

  local pillar = {
    " #%%@@@@@@@@@@@@%#*+=",
    " ##%%@@@@@@@@@%%##*+=",
    " :*#%#@%@%@@#%##**++.",
    "  .=##@%@%@@#%##++-",
    "    =*######*#**=:",
    "    -+#*%#####++=:",
    "    -*##@%%%#%**-:",
    "    -*##@%%%#%**-:",
    "    =*%#@%%%#%**=:",
    "    -+#*@%%%##++=:",
    "    =*%#@%%%#%+*=:",
    "    -+#*@%%%##++-:",
    "    =*%#@%%%#%**=:",
    "    -*##@%%%#%**-:",
    "    -*%#@%%%#%**=:",
    "    -+#*@%%%##++-:",
    "    =*%#@%%%#%**=:",
    "    -+#*@%%%##++=:",
    "    =*%#@%%%#%+*=:",
    "    -+#*@%%%##++-:",
    "    =*%#@%%%#%**=:",
    "    -+#*%%%%##++-:",
    "    -*##@%%%#%**-:",
    "    -*##@%%%#%**-:",
    "    =*%#@%%%#%**=:",
    "    -+#*@%%%##++=:",
    "    =*%#@%%%#%+*=:",
    "    -*##@%%%#%**-:",
    "    =*##@%%%#%**-:",
    "    -+#*%%%%##++-:",
    "    -*%#@%%%#%**=:",
    "    -+#*@%%%##++-:",
    "    =*%#@%%%#%**=:",
    "    -+#*%%%%##++-:",
    "    +#%@@@@@@%##+-",
    "   -##%@@@@@@%#*++:",
    "  +#%@@@@@@@@@@%#*+-",
    " -*##%%%%%%%%%###*+=:",
    ".##%%@@@@@@@@@%%##*+=",
    ".##%%@@@@@@@@@%%##*+=",
  }

  local items = {
    { key = "f", label = "Find files", action = function() require("fzf-lua").files() end },
    { key = "r", label = "Recent files", action = function() require("fzf-lua").oldfiles() end },
    { key = "/", label = "Live grep", action = function() require("fzf-lua").live_grep() end },
    { key = "e", label = "File explorer", action = function() vim.cmd "Oil --float" end },
    { key = "q", label = "Quit", action = function() vim.cmd "qall" end },
  }

  -- 0-indexed canvas: the tall column pinned to the left, the action legend set
  -- far to its right, vertically centered against the column's shaft.
  local W, H = 54, 40
  local LEFT_MARGIN = 4
  local KEY_COL, LABEL_COL = 37, 41
  local ITEM_ROWS = { 16, 17, 18, 19, 20 }

  local function build()
    local grid = {}
    for r = 0, H - 1 do
      grid[r] = {}
      for c = 0, W - 1 do
        grid[r][c] = { ch = " " }
      end
    end

    local function put(r, c, ch, hl)
      grid[r][c] = { ch = ch, hl = hl }
    end

    for i, item in ipairs(items) do
      local r = ITEM_ROWS[i]
      put(r, KEY_COL, item.key, "AlturaKey")
      for j = 1, #item.label do
        put(r, LABEL_COL + j - 1, item.label:sub(j, j), "AlturaPillar")
      end
    end

    -- Column on top, overwriting the panel where it overlaps.
    for r = 0, H - 1 do
      local line = pillar[r + 1] or ""
      for c = 1, #line do
        local ch = line:sub(c, c)
        if ch ~= " " then
          put(r, c - 1, ch, "AlturaPillar")
        end
      end
    end

    local lines, hls = {}, {}
    for r = 0, H - 1 do
      local parts, byte, cur, start = {}, 0, nil, 0
      for c = 0, W - 1 do
        local cell = grid[r][c]
        if cell.hl ~= cur then
          if cur ~= nil then
            hls[#hls + 1] = { row = r, b0 = start, b1 = byte, hl = cur }
          end
          cur, start = cell.hl, byte
        end
        parts[#parts + 1] = cell.ch
        byte = byte + #cell.ch
      end
      if cur ~= nil then
        hls[#hls + 1] = { row = r, b0 = start, b1 = byte, hl = cur }
      end
      lines[r + 1] = table.concat(parts):gsub("%s+$", "")
    end
    return lines, hls
  end

  local lines, hls = build()

  local function render(buf, win)
    local win_w = vim.api.nvim_win_get_width(win)
    local win_h = vim.api.nvim_win_get_height(win)
    local left = math.max(math.min(LEFT_MARGIN, win_w - W), 0)
    local top = math.max(math.floor((win_h - H) / 2), 0)
    local pad = string.rep(" ", left)

    local out = {}
    for _ = 1, top do
      out[#out + 1] = ""
    end
    for _, l in ipairs(lines) do
      out[#out + 1] = l == "" and "" or (pad .. l)
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, h in ipairs(hls) do
      vim.api.nvim_buf_set_extmark(buf, ns, top + h.row, left + h.b0, {
        end_col = left + h.b1,
        hl_group = h.hl,
      })
    end
    vim.bo[buf].modifiable = false

    pcall(vim.api.nvim_win_set_cursor, win, { top + ITEM_ROWS[1] + 1, left + KEY_COL })
  end

  local state = {}

  local function open()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    state.buf = buf

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].buflisted = false
    vim.bo[buf].filetype = "altura"

    vim.api.nvim_win_set_buf(win, buf)
    for opt, val in pairs {
      number = false,
      relativenumber = false,
      list = false,
      cursorline = false,
      colorcolumn = "",
      signcolumn = "no",
      spell = false,
      fillchars = "eob: ",
    } do
      vim.api.nvim_set_option_value(opt, val, { scope = "local", win = win })
    end

    for _, item in ipairs(items) do
      vim.keymap.set("n", item.key, item.action, { buffer = buf, nowait = true, silent = true })
    end

    render(buf, win)
  end

  local function set_hl()
    vim.api.nvim_set_hl(0, "AlturaPillar", { link = "Comment" })
    vim.api.nvim_set_hl(0, "AlturaKey", { bold = true })
  end

  set_hl()

  local group = vim.api.nvim_create_augroup("AlturaStart", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })

  -- Fall back to the start screen once the last real (named, listed) buffer is
  -- gone, e.g. after deleting buffers via Bdelete. Deferred so the deletion has
  -- settled; on full quit the scheduled callback simply never runs.
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function()
      vim.schedule(function()
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if
            vim.api.nvim_buf_is_valid(b)
            and vim.bo[b].buflisted
            and vim.api.nvim_buf_get_name(b) ~= ""
          then
            return
          end
        end
        local cur = vim.api.nvim_get_current_buf()
        if vim.api.nvim_buf_is_valid(cur) and vim.bo[cur].filetype ~= "altura" then
          open()
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      local buf = state.buf
      if buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "altura" then
        local win = vim.fn.bufwinid(buf)
        if win ~= -1 then
          render(buf, win)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      if vim.fn.argc() > 0 or vim.g.altura_no_start then
        return
      end
      local buf = vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].filetype ~= "" then
        return
      end
      if vim.api.nvim_buf_line_count(buf) > 1 then
        return
      end
      if (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") ~= "" then
        return
      end
      open()
    end,
  })
end)
