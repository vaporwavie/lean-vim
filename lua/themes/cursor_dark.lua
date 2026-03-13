local function hex_to_rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function blend(foreground, background, alpha)
  local fg_red, fg_green, fg_blue = hex_to_rgb(foreground)
  local bg_red, bg_green, bg_blue = hex_to_rgb(background)

  local function channel(fg_value, bg_value)
    return math.floor((alpha * fg_value) + ((1 - alpha) * bg_value) + 0.5)
  end

  return string.format(
    "#%02x%02x%02x",
    channel(fg_red, bg_red),
    channel(fg_green, bg_green),
    channel(fg_blue, bg_blue)
  )
end

local base = {
  background = "#141414",
  selection = "#303030",
  black = "#2a2a2a",
  bright_black = "#505050",
  white = "#ffffff",
  light_foreground = "#d8dee9",
  red = "#bf616a",
  green = "#a3be8c",
  yellow = "#ebcb8b",
  blue = "#81a1c1",
  purple = "#b48ead",
  cyan = "#88c0d0",
}

return {
  style = "dark",
  colors = {
    black = base.black,
    bg0 = base.background,
    bg1 = blend(base.selection, base.background, 0.45),
    bg2 = blend(base.selection, base.background, 0.75),
    bg3 = base.selection,
    bg_d = blend(base.background, "#000000", 0.8),
    bg_blue = base.blue,
    bg_yellow = base.yellow,
    fg = blend(base.white, base.light_foreground, 0.25),
    purple = base.purple,
    green = base.green,
    orange = blend(base.red, base.yellow, 0.6),
    blue = base.blue,
    yellow = base.yellow,
    cyan = base.cyan,
    red = base.red,
    grey = blend(base.light_foreground, base.bright_black, 0.3),
    light_grey = blend(base.light_foreground, base.bright_black, 0.55),
    dark_cyan = blend(base.cyan, base.background, 0.45),
    dark_red = blend(base.red, base.background, 0.45),
    dark_yellow = blend(base.yellow, base.background, 0.45),
    dark_purple = blend(base.purple, base.background, 0.45),
    diff_add = blend(base.green, base.background, 0.18),
    diff_delete = blend(base.red, base.background, 0.18),
    diff_change = blend(base.blue, base.background, 0.18),
    diff_text = blend(base.blue, base.background, 0.32),
  },
}
