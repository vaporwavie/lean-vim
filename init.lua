-- TODO:
-- 1. use enhanced bd in fzf buffer list ctrl + x
-- 5. tidy up ripgrep plugin configuration
-- 6. document everything in @utils.lua

-- Load core options, autocmds, and keymaps first
require "plugins.options"

-- Clone 'mini.nvim' manually in a way that it gets managed by 'mini.deps'
local path_package = vim.fn.stdpath "data" .. "/site/"
local mini_path = path_package .. "pack/deps/start/mini.nvim"
if not vim.loop.fs_stat(mini_path) then
  vim.cmd 'echo "Installing `mini.nvim`" | redraw'
  local clone_cmd = {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/nvim-mini/mini.nvim",
    mini_path,
  }
  vim.fn.system(clone_cmd)
  vim.cmd "packadd mini.nvim | helptags ALL"
  vim.cmd 'echo "Installed `mini.nvim`" | redraw'
end

-- Configure mini.deps helpers for configuring the plugins
require("mini.deps").setup { path = { package = path_package } }

-- Load all plugin configurations
require "plugins.colorscheme"
require "plugins.mini"
require "plugins.oil"
require "plugins.treesitter"
require "plugins.flash"
require "plugins.undotree"
require "plugins.lsp"
require "plugins.conform"
require "plugins.visual-multi"
require "plugins.fzf"
require "plugins.zen"
