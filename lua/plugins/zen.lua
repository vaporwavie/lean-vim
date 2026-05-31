-- no-neck-pain.nvim configuration for centered editing
local add, do_now = MiniDeps.add, MiniDeps.now

add { source = "shortcuts/no-neck-pain.nvim" }

do_now(function()
  require("no-neck-pain").setup {
    width = 120,
    autocmds = {
      enableOnVimEnter = false, -- off by default; toggle with <leader>z
    },
  }

  vim.keymap.set("n", "<leader>z", "<cmd>NoNeckPain<cr>", { desc = "Toggle zen mode" })
end)
