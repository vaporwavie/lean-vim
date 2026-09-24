-- The Altura palette that ~/.config/hypr/theme renders for day and night, mapped onto onedark.
local A = {}

A.path = vim.env.ALTURA_COLORS or vim.fn.expand "~/.config/hypr/generated/colors.lua"

local function blend(foreground, background, alpha)
  local function channel(hex, at)
    return tonumber(hex:sub(at, at + 1), 16)
  end
  local out = "#"
  for at = 1, 5, 2 do
    out = out
      .. string.format("%02x", math.floor(alpha * channel(foreground, at) + (1 - alpha) * channel(background, at) + 0.5))
  end
  return out
end

function A.read()
  local ok, palette = pcall(dofile, A.path)
  if ok and type(palette) == "table" and palette.bg and palette.blue then
    return palette
  end
end

function A.options(p)
  local function hex(value)
    return "#" .. value
  end
  return {
    style = p.mode == "light" and "light" or "dark",
    colors = {
      black = hex(p.bg),
      bg0 = hex(p.bg),
      bg1 = hex(p.bg_elev),
      bg2 = blend(p.line_strong, p.bg_elev, 0.5),
      bg3 = hex(p.line_strong),
      bg_d = hex(p.bg_alt),
      bg_blue = hex(p.blue),
      bg_yellow = hex(p.yellow),
      fg = hex(p.fg),
      purple = hex(p.purple),
      green = hex(p.green),
      orange = blend(p.red, p.yellow, 0.5),
      blue = hex(p.blue),
      yellow = hex(p.yellow),
      cyan = hex(p.cyan),
      red = hex(p.red),
      grey = hex(p.muted),
      light_grey = hex(p.fg_dim),
      dark_cyan = blend(p.cyan, p.bg, 0.45),
      dark_red = blend(p.red, p.bg, 0.45),
      dark_yellow = blend(p.yellow, p.bg, 0.45),
      dark_purple = blend(p.purple, p.bg, 0.45),
      diff_add = blend(p.green, p.bg, 0.18),
      diff_delete = blend(p.red, p.bg, 0.18),
      diff_change = blend(p.blue, p.bg, 0.18),
      diff_text = blend(p.blue, p.bg, 0.32),
    },
  }
end

-- theme swaps the file in with a rename, so watch the directory rather than the old inode.
function A.watch(on_change)
  local dir, name = vim.fs.dirname(A.path), vim.fs.basename(A.path)
  local handle = vim.uv.new_fs_event()
  local settle = vim.uv.new_timer()
  handle:start(dir, {}, function(_, file)
    if file == name then
      settle:start(100, 0, vim.schedule_wrap(on_change))
    end
  end)
  return handle
end

return A
