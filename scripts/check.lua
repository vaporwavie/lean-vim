local function check(condition, message)
  if not condition then
    error(message, 0)
  end
end

vim.cmd "edit init.lua"
vim.cmd "setfiletype lua"

local lua_attached = vim.wait(10000, function()
  return #vim.lsp.get_clients { bufnr = 0, name = "lua_ls" } > 0
end, 100)
check(lua_attached, "lua_ls did not attach to init.lua")

local ts_ok, ts_err = pcall(vim.treesitter.start, 0, "lua")
check(ts_ok, "lua parser did not start: " .. tostring(ts_err))

local conform_ok, conform = pcall(require, "conform")
check(conform_ok, "conform did not load: " .. tostring(conform))
check(conform.get_formatter_info("stylua", 0).available, "stylua formatter unavailable")

local prettier = conform.get_formatter_info("prettier", 0)
local prettierd = conform.get_formatter_info("prettierd", 0)
check(prettier.available or prettierd.available, "prettier/prettierd formatter unavailable")

local function formatter_names_for(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.bo.filetype = "javascript"

  local names = {}
  for _, formatter in ipairs(conform.list_formatters_to_run(0)) do
    names[formatter.name] = true
  end
  return names
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")

local plain_file = tmp .. "/plain.js"
vim.fn.writefile({ "const value = 1" }, plain_file)
local plain_formatters = formatter_names_for(plain_file)
check(not plain_formatters.biome, "biome selected without biome.json")
check(plain_formatters.prettier or plain_formatters.prettierd, "prettier fallback not selected without biome.json")

local biome_dir = tmp .. "/biome"
vim.fn.mkdir(biome_dir, "p")
vim.fn.writefile({ "{}" }, biome_dir .. "/biome.json")
local biome_file = biome_dir .. "/with-biome.js"
vim.fn.writefile({ "const value = 1" }, biome_file)
local biome_formatters = formatter_names_for(biome_file)
check(biome_formatters.biome, "biome not selected with biome.json")

vim.fn.delete(tmp, "rf")
