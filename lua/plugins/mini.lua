-- mini.nvim modules configuration
local do_now, do_later = MiniDeps.now, MiniDeps.later

-- Configure mini.nvim very important built-ins immediately
do_now(function()
  do
    require("mini.notify").setup()
    vim.keymap.set("n", "<leader>n", function()
      MiniNotify.show_history()
    end, { desc = "Show notifications history" })
  end

  do
    local statusline = require "mini.statusline"

    local function section_buffers()
      local bufs = {}
      local current = vim.api.nvim_get_current_buf()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
          local name = vim.api.nvim_buf_get_name(buf)
          -- Skip empty unnamed buffers unless it's the current one
          if name == "" and buf ~= current then
            goto continue
          end
          name = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"
          if buf == current then
            table.insert(bufs, "[" .. name .. "]")
          else
            table.insert(bufs, name)
          end
          ::continue::
        end
      end
      return table.concat(bufs, " | ")
    end

    statusline.setup {
      use_icons = false,
      content = {
        active = function()
          local mode, mode_hl = statusline.section_mode { trunc_width = 120 }
          local git = statusline.section_git { trunc_width = 40 }
          local diff = statusline.section_diff { trunc_width = 75 }
          local diagnostics = statusline.section_diagnostics { trunc_width = 75 }
          local fileinfo = statusline.section_fileinfo { trunc_width = 120 }
          local buffers = section_buffers()

          return statusline.combine_groups {
            { hl = mode_hl, strings = { mode } },
            { hl = "MiniStatuslineDevinfo", strings = { git, diff, diagnostics } },
            "%<",
            { hl = "MiniStatuslineFilename", strings = { buffers } },
            "%=",
            { hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
          }
        end,
      },
    }
  end
end)

-- Configure mini.nvim less important built-ins later
do_later(function()
  require("mini.pairs").setup()
  require("mini.git").setup()

  do
    require("mini.bufremove").setup()

    local U = require "utils"
    local overcmd = U.overcmd

    overcmd.override {
      from = { "bdelete", "bd" },
      canon = "Bdelete",
      handler = function(o)
        local buf = U.buffer.resolve(o.fargs[1])
        local name = vim.api.nvim_buf_get_name(buf)
        if name == "" then
          name = "[No Name]"
        else
          name = vim.fn.fnamemodify(name, ":t")
        end
        local ok = MiniBufremove.delete(buf, o.bang or false)
        if ok then
          vim.notify("Closed buffer: " .. name)
        end
      end,
      usercmd = {
        bang = true,
        nargs = "?",
        complete = "buffer",
        desc = "Delete buffer via mini.bufremove",
      },
      min_prefix_len = 2,
      enter_fallback = true,
    }
  end

  do
    require("mini.misc").setup()
    MiniMisc.setup_termbg_sync()
  end

  -- Commenting: gcc to toggle line, gc + motion for block
  require("mini.comment").setup()

  -- Surround: sa (add), sd (delete), sr (replace)
  -- Examples: saiw" (surround word with "), sr"' (replace " with ')
  require("mini.surround").setup()

  -- Better text objects: balanced pairs, multiline aware
  -- Extends ci(, da[, etc. beyond the vanilla behavior
  require("mini.ai").setup()

  -- Git hunk signs in the gutter + stage/reset hunk UX
  require("mini.diff").setup()

  -- Indentation scope: shows vertical line for current scope
  require("mini.indentscope").setup {
    symbol = "│",
    options = { try_as_border = true },
  }
end)
