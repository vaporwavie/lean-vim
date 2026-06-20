-- vim-visual-multi configuration for multi-cursor editing
-- Settings must be set before plugin loads
local add = MiniDeps.add

vim.g.VM_maps = {
  ["Find Under"] = "gb",
  ["Find Subword Under"] = "gb",
  ["Add Cursor Down"] = "",
  ["Add Cursor Up"] = "",
}
vim.g.VM_leader = "\\\\"
vim.g.VM_show_warnings = 0

add {
  source = "mg979/vim-visual-multi",
  checkout = "a6975e7c1ee157615bbc80fc25e4392f71c344d4",
}
