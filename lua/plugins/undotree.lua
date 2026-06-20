-- undotree configuration for undo history visualization
local add, do_now = MiniDeps.add, MiniDeps.now

add {
  source = "mbbill/undotree",
  checkout = "6fa6b57cda8459e1e4b2ca34df702f55242f4e4d",
}

do_now(function()
  vim.g.undotree_WindowLayout = 2
  vim.g.undotree_SetFocusWhenToggle = 1
  vim.keymap.set("n", "<leader>u", "<cmd>UndotreeToggle<CR>", { desc = "Toggle undo tree" })
end)
