-- Colorscheme configuration with auto dark/light mode
local add, do_now = MiniDeps.add, MiniDeps.now
local cursor_dark = require "themes.cursor_dark"

-- dark mode detection plugin
add {
  source = "f-person/auto-dark-mode.nvim",
  checkout = "e300259ec777a40b4b9e3c8e6ade203e78d15881",
}

-- little osa to detect which palette the OS is in (mac only for now)
local function is_dark_mode()
  local result = vim.fn.system "defaults read -g AppleInterfaceStyle 2>/dev/null"
  return result:match "Dark" ~= nil
end

add {
  source = "navarasu/onedark.nvim",
  checkout = "df4792accde9db0043121f32628bcf8e645d9aea",
}

local function apply_theme(opts)
  local onedark = require "onedark"

  if vim.g.onedark_config and vim.g.onedark_config.loaded then
    onedark.set_options("colors", {})
    onedark.set_options("highlights", {})
  end

  onedark.setup(opts)
  onedark.load()
end

local function load_dark()
  vim.env.BAT_THEME = "OneHalfDark"
  apply_theme(cursor_dark)
end

local function load_light()
  vim.env.BAT_THEME = "OneHalfLight"
  apply_theme { style = "light" }
end

do_now(function()
  if is_dark_mode() then
    load_dark()
  else
    load_light()
  end

  require("auto-dark-mode").setup {
    update_interval = 3000,
    set_dark_mode = load_dark,
    set_light_mode = load_light,
  }
end)
