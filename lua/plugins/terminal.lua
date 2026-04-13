-- floating terminal toggle (no external plugin)
local do_later = MiniDeps.later

do_later(function()
  local term_buf, term_win, term_chan

  local border = { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" }

  local function float_config()
    local w = math.floor(vim.o.columns * 0.8)
    local h = math.floor(vim.o.lines * 0.8)
    return {
      relative = "editor",
      width = w,
      height = h,
      col = math.floor((vim.o.columns - w) / 2),
      row = math.floor((vim.o.lines - h) / 2),
      style = "minimal",
      border = border,
    }
  end

  local function is_term_alive()
    if not term_buf or not vim.api.nvim_buf_is_valid(term_buf) then return false end
    if not term_chan then return false end
    return vim.fn.jobwait({ term_chan }, 0)[1] == -1
  end

  local function hide()
    if term_win and vim.api.nvim_win_is_valid(term_win) then
      vim.api.nvim_win_close(term_win, true)
      term_win = nil
    end
  end

  local function set_buf_keymaps(buf)
    local function bmap(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end

    bmap("t", "<Esc><Esc>", function()
      vim.cmd.stopinsert()
      hide()
    end, "Hide terminal")

    bmap("t", "<C-`>", function()
      vim.cmd.stopinsert()
      hide()
    end, "Toggle terminal")

    bmap("n", "q", hide, "Hide terminal")
    bmap("n", "<Esc>", hide, "Hide terminal")
  end

  local function toggle()
    -- window visible → hide it
    if term_win and vim.api.nvim_win_is_valid(term_win) then
      hide()
      return
    end

    -- buffer alive but hidden → reopen
    if is_term_alive() then
      term_win = vim.api.nvim_open_win(term_buf, true, float_config())
      vim.cmd.startinsert()
      return
    end

    -- dead or absent → fresh terminal
    term_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[term_buf].bufhidden = "hide"
    term_win = vim.api.nvim_open_win(term_buf, true, float_config())
    term_chan = vim.fn.termopen(vim.o.shell)
    set_buf_keymaps(term_buf)
    vim.cmd.startinsert()
  end

  vim.keymap.set({ "n", "t" }, "<C-`>", toggle, { desc = "Toggle terminal" })

  vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.signcolumn = "no"
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if term_win and vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_set_config(term_win, float_config())
      end
    end,
  })
end)
