-- Colorscheme configuration with auto dark/light mode
local add, do_now = MiniDeps.add, MiniDeps.now

-- dark mode detection plugin
add { source = "f-person/auto-dark-mode.nvim" }

-- little osa to detect which palette the OS is in (mac only for now)
local function is_dark_mode()
  local result = vim.fn.system "defaults read -g AppleInterfaceStyle 2>/dev/null"
  return result:match "Dark" ~= nil
end

add { source = "navarasu/onedark.nvim" }

local function load_dark()
  require("onedark").setup { style = "dark" }
  require("onedark").load()
end

local function load_light()
  require("onedark").setup { style = "light" }
  require("onedark").load()
end

do_now(function()
  if is_dark_mode() then
    load_dark()
  else
    load_light()
  end

  require("auto-dark-mode").setup {
    update_interval = 1000,
    set_dark_mode = load_dark,
    set_light_mode = load_light,
  }
end)
