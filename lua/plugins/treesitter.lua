-- nvim-treesitter (main branch) + textobjects for Neovim 0.11+
local add, do_now = MiniDeps.add, MiniDeps.now

add {
  source = "nvim-treesitter/nvim-treesitter",
  checkout = "main",
  hooks = {
    post_checkout = function()
      vim.cmd [[ :TSUpdate ]]
    end,
  },
}

add { source = "nvim-treesitter/nvim-treesitter-textobjects", checkout = "main" }

do_now(function()
  -- stylua: ignore
  local language_grammars = {
    "astro", "javascript", "typescript", "tsx", "css", "html", "scss",
    "cmake", "cpp", "c",
    "lua", "bash", "xml", "markdown", "markdown_inline",
  }

  require("nvim-treesitter").setup {
    install_dir = vim.fn.stdpath "data" .. "/site",
  }
  require("nvim-treesitter").install(language_grammars)

  vim.api.nvim_create_autocmd("FileType", {
    pattern = {
      "astro",
      "javascript",
      "typescript",
      "typescriptreact",
      "javascriptreact",
      "tsx",
      "css",
      "html",
      "scss",
      "cmake",
      "cpp",
      "c",
      "lua",
      "bash",
      "sh",
      "xml",
      "markdown",
      "markdown_inline",
    },
    callback = function()
      pcall(vim.treesitter.start)
    end,
  })

  require("nvim-treesitter-textobjects").setup {
    select = { lookahead = true },
    move = { set_jumps = true },
  }

  local select = function(capture)
    return function()
      require("nvim-treesitter-textobjects.select").select_textobject(capture, "textobjects")
    end
  end
  local goto_next = function(capture)
    return function()
      require("nvim-treesitter-textobjects.move").goto_next_start(capture, "textobjects")
    end
  end
  local goto_prev = function(capture)
    return function()
      require("nvim-treesitter-textobjects.move").goto_previous_start(capture, "textobjects")
    end
  end

  local map = vim.keymap.set
  map({ "x", "o" }, "af", select "@function.outer")
  map({ "x", "o" }, "if", select "@function.inner")
  map({ "x", "o" }, "ac", select "@class.outer")
  map({ "x", "o" }, "ic", select "@class.inner")
  map({ "x", "o" }, "aa", select "@parameter.outer")
  map({ "x", "o" }, "ia", select "@parameter.inner")

  map({ "n", "x", "o" }, "]f", goto_next "@function.outer")
  map({ "n", "x", "o" }, "]c", goto_next "@class.outer")
  map({ "n", "x", "o" }, "[f", goto_prev "@function.outer")
  map({ "n", "x", "o" }, "[c", goto_prev "@class.outer")
end)
