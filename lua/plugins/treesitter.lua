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

-- Separate add so nvim-treesitter is on the rtp before textobjects'
-- plugin/*.vim auto-requires `nvim-treesitter.configs`.
add { source = "nvim-treesitter/nvim-treesitter-textobjects", checkout = "master" }

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
    textobjects = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          ["ic"] = "@class.inner",
          ["aa"] = "@parameter.outer",
          ["ia"] = "@parameter.inner",
        },
      },
      move = {
        enable = true,
        set_jumps = true,
        goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
        goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
      },
    },
  }
end)
