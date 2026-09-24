-- Colorscheme configuration with auto dark/light mode
local add, do_now = MiniDeps.add, MiniDeps.now
local cursor_dark = require "themes.cursor_dark"
local altura = require "themes.altura"

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

local function load_altura()
  local palette = altura.read()
  if not palette then
    return
  end
  local light = palette.mode == "light"
  vim.env.BAT_THEME = light and "OneHalfLight" or "OneHalfDark"
  -- onedark reads 'background' but never sets it, and a stale "light" forces its light style.
  vim.o.background = light and "light" or "dark"
  apply_theme(altura.options(palette))
end

do_now(function()
  -- Under Hyprland the theme script owns day and night, so follow its palette instead of the portal.
  if altura.read() then
    load_altura()
    altura.watch(load_altura)
    return
  end

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
