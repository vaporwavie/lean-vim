-- LSP configuration: blink.cmp + mason + lspconfig
local add, do_now = MiniDeps.add, MiniDeps.now

add {
  source = "saghen/blink.cmp",
  depends = {
    { source = "mason-org/mason.nvim", checkout = "v2.1.0" },
    { source = "mason-org/mason-lspconfig.nvim", checkout = "v2.1.0" },
    { source = "neovim/nvim-lspconfig", checkout = "v2.1.0" },
  },
  checkout = "v1.7.0",
}

do_now(function()
  require("mason").setup()
  require("blink.cmp").setup {
    sources = {
      default = { "lsp", "path" },
    },
    keymap = { preset = "enter", ["<CR>"] = { "select_and_accept", "fallback" } },
  }

  local builtin = vim.lsp.protocol.make_client_capabilities()
  local blink = require("blink.cmp").get_lsp_capabilities({}, false)
  local caps = vim.tbl_deep_extend("force", builtin, blink)

  require("mason-lspconfig").setup {
    ensure_installed = require("utils").mason_lspconfig(require "mason-lspconfig").server_to_lsp {
      "lua_ls",
      "vtsls",
      "biome",
      "stylua",
      "prettier",
      "tailwindcss-language-server",
    },
    automatic_enable = true,
  }

  vim.lsp.config("*", { capabilities = caps })

  vim.keymap.set("n", "gd", function()
    vim.lsp.buf.definition()
  end, { desc = "Go to definition" })
  vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic" })
  -- grn = vim.lsp.buf.rename()
  -- gra = vim.lsp.buf.code_action()
end)
