-- LSP configuration: blink.cmp + native vim.lsp.enable
-- Server binaries come from Homebrew (see install.sh), not mason:
-- lua-language-server, vtsls, biome, tailwindcss-language-server
local add, do_now = MiniDeps.add, MiniDeps.now

add {
  source = "saghen/blink.cmp",
  depends = {
    {
      source = "neovim/nvim-lspconfig",
      checkout = "ed19590a3a9792901553c388d1aadafce012f80d",
    },
  },
  checkout = "78336bc89ee5365633bcf754d93df01678b5c08f",
}

do_now(function()
  require("blink.cmp").setup {
    sources = {
      default = { "lsp", "path" },
    },
    keymap = { preset = "enter", ["<CR>"] = { "select_and_accept", "fallback" } },
  }

  vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
  vim.lsp.commands.setContext = function() end

  vim.lsp.config("vtsls", {
    settings = {
      typescript = {
        tsserver = { maxTsServerMemory = 8192 },
      },
      vtsls = {
        experimental = {
          -- Filter completions server-side: smaller payloads on big monorepos
          completion = { enableServerSideFuzzyMatch = true },
        },
      },
    },
  })

  vim.lsp.enable { "lua_ls", "vtsls", "biome", "tailwindcss" }

  vim.keymap.set("n", "gd", function()
    vim.lsp.buf.definition()
  end, { desc = "Go to definition" })
  vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic" })
  vim.keymap.set({ "n", "i" }, "<C-Space>", function()
    vim.diagnostic.open_float(nil, { focus = false, scope = "cursor" })
  end, { desc = "Show diagnostic at cursor" })
  -- grn = vim.lsp.buf.rename()
  -- gra = vim.lsp.buf.code_action()
end)
