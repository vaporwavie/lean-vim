-- conform.nvim configuration for formatting
local add, do_later = MiniDeps.add, MiniDeps.later

add {
  source = "stevearc/conform.nvim",
  checkout = "619363c30309d29ffa631e67c8183f2a72caa373",
}

do_later(function()
  local conform = require "conform"

  local prettier_formatters = {
    "prettierd",
    "prettier",
    stop_after_first = true,
  }

  local function js_formatters(bufnr)
    if vim.fs.root(bufnr, { "biome.json", "biome.jsonc" }) and conform.get_formatter_info("biome", bufnr).available then
      return { "biome" }
    end
    return prettier_formatters
  end

  local formatters_by_ft = {
    lua = { "stylua" },
  }
  for _, ft in ipairs { "javascript", "typescript", "javascriptreact", "typescriptreact", "json", "jsonc" } do
    formatters_by_ft[ft] = js_formatters
  end

  conform.setup {
    formatters_by_ft = formatters_by_ft,
    format_on_save = {
      timeout_ms = 1000,
      lsp_format = "fallback",
    },
  }

  vim.keymap.set("n", "<leader>r", function()
    conform.format({ async = true }, function(_, did_edit)
      if did_edit then
        vim.notify "Successfully formatted"
      end
    end)
  end, { desc = "Format current buffer asynchronously" })
end)
