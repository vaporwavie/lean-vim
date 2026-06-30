-- fff.nvim configuration for fast frecency-ranked file/grep search
local add, do_later = MiniDeps.add, MiniDeps.later

add {
  source = "dmtrKovalenko/fff.nvim",
  checkout = "v0.9.6",
}

do_later(function()
  local lib = vim.fn.stdpath "data" .. "/site/pack/deps/opt/fff.nvim/target/release/libfff_nvim.dylib"
  if vim.fn.filereadable(lib) == 0 then
    require("fff.download").download_or_build_binary()
  end

  require("fff").setup {}

  local fff = require "fff"
  vim.keymap.set("n", "<leader>f", fff.find_files, { desc = "FFFind files" })
  vim.keymap.set("n", "<C-p>", fff.find_files, { desc = "FFFind files" })
  vim.keymap.set("n", "<C-f>", fff.find_files, { desc = "FFFind files" })
  vim.keymap.set("n", "<leader>/", fff.live_grep, { desc = "Live grep (fff)" })
  vim.keymap.set({ "n", "x" }, "<leader>w", function()
    local query
    if vim.fn.mode() == "n" then
      query = vim.fn.expand "<cword>"
    else
      query = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
      query = type(query) == "table" and table.concat(query, "\n") or query
    end
    fff.live_grep { query = query }
  end, { desc = "Grep word/selection (fff)" })
end)
