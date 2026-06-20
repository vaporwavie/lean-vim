-- flash.nvim configuration for quick jumps
local add, do_later = MiniDeps.add, MiniDeps.later

add {
  source = "folke/flash.nvim",
  checkout = "fcea7ff883235d9024dc41e638f164a450c14ca2",
}

do_later(function()
  local flash = require "flash"
  flash.setup {
    highlight = {
      backdrop = false,
    },
    modes = {
      char = { enabled = false }, -- disable f/F/t/T enhancement, keep it simple
    },
  }
  vim.keymap.set({ "n", "x", "o" }, "s", flash.jump, { desc = "Flash jump" })
  vim.keymap.set({ "n", "x", "o" }, "S", flash.treesitter, { desc = "Flash treesitter" })
end)
