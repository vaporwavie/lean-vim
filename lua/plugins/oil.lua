-- oil.nvim configuration for filesystem management
local add, do_later = MiniDeps.add, MiniDeps.later

add {
  source = "stevearc/oil.nvim",
  checkout = "master",
}

do_later(function()
  require("oil").setup {
    default_file_explorer = true,
    watch_for_changes = true,
    view_options = {
      show_hidden = true,
    },
    float = {
      padding = 4,
      max_width = 0.5,
      max_height = 0.5,
      border = { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" },
    },
  }

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "oil",
    callback = function(ev)
      local function map(lhs)
        vim.keymap.set("n", lhs, function()
          -- only close if the current Oil window is a float
          local cfg = vim.api.nvim_win_get_config(0)
          if cfg and (cfg.relative or "") ~= "" then
            require("oil").close()
          end
        end, { buffer = ev.buf, desc = "Close Oil float" })
      end
      map "q"
      map "<Esc>" -- normal-mode only; won't eat Visual-mode <Esc>
    end,
  })

  vim.keymap.set("n", "-", "<cmd>Oil --float<CR>", { desc = "Open file explorer" })
end)
