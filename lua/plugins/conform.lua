-- conform.nvim configuration for formatting
local fun = require "fun"
local add, do_later = MiniDeps.add, MiniDeps.later

add {
  source = "stevearc/conform.nvim",
  checkout = "master",
}

do_later(function()
  local conform = require "conform"

  local formatters_by_ft = fun
    .iter({ "javascript", "typescript", "javascriptreact", "typescriptreact", "json", "jsonc" })
    :map(function(ft)
      return ft,
        conform.get_formatter_info("biome").available and { "biome" } or {
          "prettierd",
          "prettier",
          stop_after_first = true,
        }
    end)
    :foldl(function(acc, k, v)
      acc[k] = v
      return acc
    end, {})

  formatters_by_ft.lua = { "stylua" }

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
