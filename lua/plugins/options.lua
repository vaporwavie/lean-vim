-- Core Neovim options and settings
vim.g.mapleader = " "

-- Disable unused built-in plugins to shave startup time
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_tutor = 1
vim.g.loaded_tohtml = 1
vim.opt.termguicolors = true
vim.opt.ttyfast = true
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.clipboard = "unnamedplus"
local swap_dir = vim.fn.stdpath "state" .. "/swap//"
vim.fn.mkdir(swap_dir, "p")
vim.opt.directory = { swap_dir }
vim.opt.swapfile = true
vim.opt.backup = false
vim.opt.undodir = os.getenv "HOME" .. "/.vim/undodir"
vim.opt.undofile = true
vim.opt.smartindent = true
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.scrolloff = 8
vim.opt.linespace = 4
vim.opt.ruler = false
vim.opt.cmdheight = 0
vim.opt.ttimeoutlen = 10

-- Pick up edits made outside Neovim (agents, formatters, git) without :e
-- 'autoread' is on by default; it only acts when a check runs, so force one
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermLeave" }, {
  callback = function()
    if vim.fn.getcmdwintype() == "" then
      vim.cmd "checktime"
    end
  end,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  callback = function()
    vim.notify("File changed on disk; buffer reloaded", vim.log.levels.WARN)
  end,
})

-- Highlight yanked text briefly
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank { higroup = "IncSearch", timeout = 150 }
  end,
})

-- Restore cursor position when reopening files
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- Disable macro recording and playback in Neovim
vim.keymap.set({ "n", "x" }, "q", "<nop>", { desc = "Disable macro recording" })
vim.keymap.set({ "n", "x" }, "@", "<nop>", { desc = "Disable macro playback" })
vim.keymap.set({ "n", "x" }, "Q", "<nop>", { desc = "Disable Ex-mode (legacy)" })
vim.keymap.set("n", "@@", "<nop>", { desc = "Disable @@ macro replay" })
vim.api.nvim_create_user_command("Normal", function()
  vim.notify("Macro execution disabled", vim.log.levels.WARN)
end, {})
