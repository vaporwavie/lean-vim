-- fzf-lua configuration for fuzzy finding
local add, do_later = MiniDeps.add, MiniDeps.later

add {
  source = "ibhagwan/fzf-lua",
  checkout = "main",
}

do_later(function()
  local fzf = require "fzf-lua"

  fzf.setup {
    "max-perf",
    fzf_colors = true,
    fzf_opts = {
      ["--ansi"] = "",
      ["--scrollbar"] = "██",
    },
    files = {
      fd_opts = "--color=never --type f --hidden --follow --exclude .git --exclude node_modules --exclude .next --exclude dist --exclude build --exclude vendor",
    },
    grep = {
      rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4096 -g '!.git' -g '!node_modules' -g '!.next' -g '!dist' -g '!build' -g '!vendor'",
      fzf_opts = { ["--ansi"] = "" },
    },
    previewers = {
      bat = {
        cmd = "bat",
        args = "--color=always --style=changes",
      },
    },
    winopts = {
      height = 0.55,
      width = 1,
      row = 1,
      col = 0,
      backdrop = 50,
      border = { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" },
      preview = {
        border = "none",
        vertical = "down:45%,border-left",
        horizontal = "right:60%,border-left",
        winopts = {
          hidden = "hidden",
        },
      },
    },
  }

  local fzf_utils = require("utils").fzf_lua_utils(fzf)

  local function _parse_diag_entry(entry)
    if type(entry) == "table" then
      -- when fzf-lua passes rich entries
      return entry.path or entry.filename, entry.lnum, entry.col, entry.severity, entry.code, entry.text
    end
    -- fallback: parse "file:lnum:col: rest"
    local file, l, c, rest = tostring(entry):match "^([^:]+):(%d+):(%d+):%s*(.*)$"
    return file, tonumber(l), tonumber(c), nil, nil, rest
  end

  local function copy_diagnostic(selected)
    local e = selected and selected[1]
    if not e then
      return
    end
    local file, lnum, col, severity, code, text = _parse_diag_entry(e)
    if not file then
      return
    end
    -- compose a nice, compact line
    local sev = severity and (tostring(severity):upper()) or nil
    local codepart = code and ("(" .. code .. ")") or nil
    local meta = vim.tbl_filter(function(s)
      return s and #s > 0
    end, { sev, codepart })
    local meta_str = #meta > 0 and (" " .. table.concat(meta, " ")) or ""
    local line = string.format("%s:%d:%d:%s%s", file, lnum or 1, col or 1, (text or ""):gsub("^%s+", ""), meta_str)

    vim.fn.setreg("+", line) -- system clipboard
    vim.fn.setreg('"', line) -- unnamed register (nice for `p`)
    vim.notify("Copied diagnostic:\n" .. line)
  end

  vim.keymap.set("n", "<leader>ld", function()
    fzf.diagnostics_document {
      actions = {
        ["y"] = copy_diagnostic,
      },
      fzf_opts = { ["--preview-window"] = "right:60%:wrap:+{2}", ["--header"] = ":: y to yank the diagnostic" },
    }
  end, { desc = "Document diagnostics (fzf-lua) with copy" })

  vim.keymap.set("n", "<leader>f", fzf.files, { desc = "Find files" })
  vim.keymap.set("n", "<C-p>", fzf.files, { desc = "Find files" })
  vim.keymap.set("n", "<C-f>", fzf.live_grep, { desc = "Search in project" })
  vim.keymap.set("n", "<leader>s", fzf.lsp_document_symbols, { desc = "Symbols" })
  vim.keymap.set("n", "gr", fzf.lsp_references, { desc = "References" })
  vim.keymap.set("n", "<leader>b", fzf.buffers, { desc = "Navigate through open buffers" })

  local function get_navigable_buffers()
    local bufs = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
        local name = vim.api.nvim_buf_get_name(buf)
        if name ~= "" then
          table.insert(bufs, buf)
        end
      end
    end
    return bufs
  end

  local function navigate_buffer(direction)
    local bufs = get_navigable_buffers()
    if #bufs == 0 then
      return
    end
    local current = vim.api.nvim_get_current_buf()
    local idx = 1
    for i, buf in ipairs(bufs) do
      if buf == current then
        idx = i
        break
      end
    end
    if direction == "next" then
      idx = idx % #bufs + 1
    else
      idx = (idx - 2) % #bufs + 1
    end
    vim.api.nvim_set_current_buf(bufs[idx])
  end

  vim.keymap.set("n", "<leader>[", function()
    navigate_buffer "prev"
  end, { desc = "Previous buffer" })
  vim.keymap.set("n", "<leader>]", function()
    navigate_buffer "next"
  end, { desc = "Next buffer" })
  vim.keymap.set("n", "<leader>q", "<cmd>Bdelete<CR>", { desc = "Delete current buffer" })
  vim.keymap.set("n", "<leader>/", fzf_utils.live_ripgrep, { desc = "Live grep" })
  vim.keymap.set("n", "<leader>?", fzf_utils.pick_dirs_then_live_ripgrep, { desc = "Pick dirs then live ripgrep" })

  vim.keymap.set("n", "<leader>g", fzf.git_diff, { desc = "Git files" })
  vim.keymap.set("n", "<leader>vh", fzf.help_tags, { desc = "Help tags" })
end)
