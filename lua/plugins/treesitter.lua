-- nvim-treesitter configuration for syntax and textobjects
local add, do_now = MiniDeps.add, MiniDeps.now

add {
  source = "nvim-treesitter/nvim-treesitter",
  checkout = "master",
  hooks = {
    post_checkout = function()
      vim.cmd [[ :TSUpdate ]]
    end,
  },
}

do_now(function()
  -- stylua: ignore
  local language_grammars = {
    "astro", "javascript", "typescript", "tsx", "css", "html", "scss",
    "cmake", "cpp", "c",
    "lua", "bash", "xml", "markdown",
  }
  require("nvim-treesitter.configs").setup {
    ensure_installed = language_grammars,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = { "markdown" },
    },
  }
end)
