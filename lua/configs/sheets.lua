-- Spreadsheets in Neovim
--   csv / tsv  : csvview.nvim draws them as a table (│ between columns, header stays on top)
--                <Tab> / <S-Tab> next / previous cell · if / af select a cell
--                :CsvViewToggle switches the table off and on
--   xlsx / xlsm: opened read-only, one sheet at a time, as a csv table (needs python + openpyxl:
--                `python -m pip install openpyxl`)
--                ]s / [s next / previous sheet · gs pick a sheet · the winbar lists them
local M = {}

function M.csvview()
  require("csvview").setup {
    view = {
      display_mode = "border",
      sticky_header = { enabled = true, separator = "─" },
    },
    keymaps = {
      textobject_field_inner = { "if", mode = { "o", "x" } },
      textobject_field_outer = { "af", mode = { "o", "x" } },
      jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
      jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
    },
  }
  local function on(buf)
    if vim.b[buf].csvview_off then
      return
    end
    vim.wo.wrap = false -- a table scrolls sideways (zl / zh, or the mouse)
    pcall(require("csvview").enable, buf)
  end
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "csv", "tsv" },
    callback = function(ev)
      on(ev.buf)
    end,
  })
  -- the buffer that made the plugin load
  local ft = vim.bo.filetype
  if ft == "csv" or ft == "tsv" then
    on(vim.api.nvim_get_current_buf())
  end
end

-- ---------------------------------------------------------------------------
-- Excel files
-- ---------------------------------------------------------------------------

local reader = [[
import sys, json, datetime
try:
    import openpyxl
except ImportError:
    print(json.dumps({"error": "openpyxl is missing: python -m pip install openpyxl"}))
    sys.exit()
def cell(v):
    if v is None:
        return ""
    if isinstance(v, (datetime.datetime, datetime.date, datetime.time)):
        if isinstance(v, datetime.datetime):
            return v.date().isoformat() if v.time() == datetime.time() else v.isoformat(sep=" ")
        return v.isoformat()
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)
try:
    wb = openpyxl.load_workbook(sys.argv[1], read_only=True, data_only=True)
    wf = None  # formulas: shown where the file has no saved result
    out = []
    for n, ws in enumerate(wb.worksheets):
        rows = [list(r) for r in ws.iter_rows(values_only=True)]
        if any(v is None for r in rows for v in r):
            if wf is None:
                wf = openpyxl.load_workbook(sys.argv[1], read_only=True)
            for i, r in enumerate(wf.worksheets[n].iter_rows(values_only=True)):
                for j, f in enumerate(r):
                    if i < len(rows) and j < len(rows[i]) and rows[i][j] is None and isinstance(f, str) and f.startswith("="):
                        rows[i][j] = f
        rows = [[cell(v) for v in r] for r in rows]
        while rows and not any(rows[-1]):
            rows.pop()
        out.append({"name": ws.title, "rows": rows})
    sys.stdout.buffer.write(json.dumps({"sheets": out}).encode("utf-8"))
except Exception as e:
    print(json.dumps({"error": str(e)}))
]]

local function csv_line(row)
  local out = {}
  for i, v in ipairs(row) do
    v = v:gsub("[\r\n]+", " ")
    if v:find '[,"]' then
      v = '"' .. v:gsub('"', '""') .. '"'
    end
    out[i] = v
  end
  return table.concat(out, ",")
end

local function winbar(buf)
  local s = vim.b[buf].sheets
  if not s then
    return
  end
  local parts = {}
  for i, sh in ipairs(s) do
    if i == vim.b[buf].sheet then
      parts[#parts + 1] = "%#TabLineSel# " .. sh.name .. " %*"
    else
      parts[#parts + 1] = "%#Comment# " .. sh.name .. " %*"
    end
  end
  local hint = #s > 1 and "%#Comment#   ]s [s gs%*" or ""
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win].winbar = table.concat(parts, "") .. hint
  end
end

local function show(buf, i)
  local s = vim.b[buf].sheets
  if not s or not s[i] then
    return
  end
  local lines = {}
  for _, row in ipairs(s[i].rows) do
    lines[#lines + 1] = csv_line(row)
  end
  if #lines == 0 then
    lines = { "(empty sheet)" }
  end
  vim.b[buf].sheet = i
  local cv = require "csvview"
  if cv.is_enabled(buf) then
    cv.disable(buf)
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = "csv" -- loads csvview and draws the table
  pcall(require("csvview").enable, buf)
  winbar(buf)
end

local function open(ev)
  local buf, path = ev.buf, vim.fn.fnamemodify(ev.file, ":p")
  vim.bo[buf].buftype = "nofile" -- read-only: there's nothing to save back
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "reading " .. vim.fn.fnamemodify(path, ":t") .. "…" })
  local r = vim.system({ "python", "-c", reader, path }, { text = true }):wait()
  local ok, data = pcall(vim.json.decode, r.stdout or "")
  if not ok or type(data) ~= "table" or data.error then
    local why = (ok and type(data) == "table" and data.error) or (r.stderr ~= "" and r.stderr) or "python didn't answer"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "couldn't read this sheet: " .. why })
    vim.bo[buf].modifiable = false
    return
  end
  vim.b[buf].sheets = data.sheets
  show(buf, 1)
  local function step(d)
    return function()
      local n = #vim.b[buf].sheets
      show(buf, (vim.b[buf].sheet - 1 + d) % n + 1)
    end
  end
  vim.keymap.set("n", "]s", step(1), { buffer = buf, desc = "Next sheet" })
  vim.keymap.set("n", "[s", step(-1), { buffer = buf, desc = "Previous sheet" })
  vim.keymap.set("n", "gs", function()
    local names = vim.tbl_map(function(s)
      return s.name
    end, vim.b[buf].sheets)
    vim.ui.select(names, { prompt = "Sheet" }, function(_, i)
      if i then
        show(buf, i)
      end
    end)
  end, { buffer = buf, desc = "Pick a sheet" })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    buffer = buf,
    callback = function()
      winbar(buf)
    end,
  })
end

vim.api.nvim_create_autocmd("BufReadCmd", {
  pattern = { "*.xlsx", "*.xlsm" },
  callback = open,
})

return M
