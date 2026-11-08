-- Todo lists + notes in a popup, from anywhere. Plain markdown files, checkmate draws the boxes.
-- Everything lives in one folder. Change it here:
local root = "~/Documents/Coding/Notebook"

--   <leader>jt  pick a todo list      <leader>jn  pick a note
--   In the picker:  enter open   "+ New" entry makes one (asks for a title)
--                   ctrl+e rename   ctrl+d delete
--   In the popup (keys shown in its bottom border):
--     enter tick / untick   o new todo   q / Esc close (saves)
--     <leader>Tp @priority   <leader>Ta archive done ones   (more checkmate keys: <leader>T...)
local M = {}

local kinds = {
  todos = { dir = "todos", label = "Todo lists", icon = "󰄲", start = "- [ ] " },
  notes = { dir = "notes", label = "Notes", icon = "󰠮", start = "" },
}

local function folder(kind)
  local d = vim.fs.normalize(vim.fn.expand(root) .. "/" .. kinds[kind].dir)
  vim.fn.mkdir(d, "p")
  return d
end

-- the title is the file's first "# heading", or its name
local function title_of(path)
  local f = io.open(path, "r")
  local first = f and f:read "*l" or ""
  if f then f:close() end
  local t = first and first:match "^#%s+(.-)%s*$"
  return (t and t ~= "") and t or vim.fn.fnamemodify(path, ":t:r")
end

local function file_name(title)
  return (title:gsub('[\\/:*?"<>|]', ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ---------------------------------------------------------------------------
-- small dialogs (rename / new title / delete), drawn like the popups
-- ---------------------------------------------------------------------------
-- key hints for a border: { {"key", "what"}, ... } -> " key what  ·  key what "
local function hints(list)
  local out = { { " ", "FloatBorder" } }
  for i, h in ipairs(list) do
    if i > 1 then table.insert(out, { "  ·  ", "FloatBorder" }) end
    table.insert(out, { h[1], "Special" })
    table.insert(out, { " " .. h[2], "Comment" })
  end
  table.insert(out, { " ", "FloatBorder" })
  return out
end

local function width_of(chunks)
  local n = 0
  for _, c in ipairs(chunks) do n = n + vim.fn.strdisplaywidth(c[1]) end
  return n
end

-- o.input: one-line text box (o.default); otherwise a yes / no question (o.text)
-- a dark see-through layer over everything, so the dialog stands out
local function backdrop()
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor", style = "minimal", focusable = false, zindex = 150,
    width = vim.o.columns, height = vim.o.lines, row = 0, col = 0,
  })
  vim.api.nvim_set_hl(0, "NotebookBackdrop", { bg = "#000000" })
  vim.wo[win].winhighlight = "Normal:NotebookBackdrop"
  vim.wo[win].winblend = 45
  return win
end

local function dialog(o)
  local shade = backdrop()
  local buf = vim.api.nvim_create_buf(false, true)
  local foot = hints(o.hints)
  local w = math.max(44, width_of(foot) + 4, vim.fn.strdisplaywidth(o.text or o.default or "") + 8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded", zindex = 200,
    width = w, height = 1, row = math.floor(vim.o.lines / 2) - 2, col = math.floor((vim.o.columns - w) / 2),
    title = { { " " .. o.title .. " ", o.title_hl or "Title" } }, title_pos = "center",
    footer = foot, footer_pos = "center",
  })
  if o.border_hl then vim.wo[win].winhighlight = "FloatBorder:" .. o.border_hl end
  local done = false
  local function finish(value)
    if done then return end
    done = true
    vim.cmd "stopinsert"
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_win_is_valid(shade) then vim.api.nvim_win_close(shade, true) end
    vim.schedule(function() o.on_done(value) end)
  end
  local k = { buffer = buf, nowait = true }
  if o.input then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { o.default or "" })
    vim.cmd "startinsert!"
    vim.keymap.set({ "i", "n" }, "<CR>", function() finish(vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")) end, k)
    vim.keymap.set({ "i", "n" }, "<Esc>", function() finish(nil) end, k)
    vim.keymap.set("n", "q", function() finish(nil) end, k)
  else
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  " .. o.text })
    vim.bo[buf].modifiable = false
    for _, key in ipairs { "y", "Y" } do vim.keymap.set("n", key, function() finish(true) end, k) end
    for _, key in ipairs { "n", "N", "q", "<Esc>" } do vim.keymap.set("n", key, function() finish(false) end, k) end
  end
  -- clicking or jumping away cancels
  vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = function() finish(nil) end })
end

-- ---------------------------------------------------------------------------
-- popup
-- ---------------------------------------------------------------------------
local function is_todo(line)
  return line:match "^%s*[-*+] %[[ xX]%]"
end

local function open_popup(path, kind)
  -- already open: just jump to it
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.w[w].notebook and vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))) == path then
      return vim.api.nvim_set_current_win(w)
    end
  end
  local buf = vim.fn.bufadd(path)
  -- open it even if another Nvim has it open too (no "swap file" warning in the way)
  local sm = vim.o.shortmess
  vim.opt.shortmess:append "A"
  pcall(vim.fn.bufload, buf)
  vim.o.shortmess = sm
  vim.bo[buf].buflisted = false
  -- the keys you can use, shown in the bottom border
  local foot = hints {
    { "enter", "tick" }, { "o", "new todo" }, { "spc Tp", "priority" }, { "spc Ta", "archive done" }, { "q", "close" },
  }
  local W, H = vim.o.columns, vim.o.lines
  local w = math.min(W - 4, math.max(math.floor(W * 0.6), width_of(foot) + 4))
  local h = math.floor(H * 0.7)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", border = "rounded",
    title = " " .. kinds[kind].icon .. " " .. title_of(path) .. " ", title_pos = "center",
    footer = foot, footer_pos = "center",
    width = w, height = h, row = math.floor((H - h) / 2) - 1, col = math.floor((W - w) / 2),
  })
  vim.w[win].notebook = true
  local function opts(desc) return { buffer = buf, nowait = true, desc = desc } end
  for _, key in ipairs { "q", "<Esc>" } do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, false) end
    end, opts "Close popup")
  end
  -- Enter ticks / unticks the todo under the cursor (on other lines it just moves down)
  vim.keymap.set("n", "<CR>", function()
    if is_todo(vim.api.nvim_get_current_line()) then require("checkmate").toggle() else vim.cmd "normal! +" end
  end, opts "Tick / untick")
  -- o starts a new todo below the cursor
  vim.keymap.set("n", "o", function()
    if is_todo(vim.api.nvim_get_current_line()) then
      require("checkmate").create()
    else
      vim.api.nvim_feedkeys("o- [ ] ", "n", false)
    end
  end, opts "New todo")
  -- save on close; nested so checkmate turns □/■ back into [ ] / [x] in the file
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win), once = true, nested = true,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function() vim.cmd "silent write" end)
      end
    end,
  })
end

-- ---------------------------------------------------------------------------
-- picker actions
-- ---------------------------------------------------------------------------
local function close_buffer(path)
  local b = vim.fn.bufnr(path)
  if b ~= -1 then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
end

local function create(kind, reopen)
  dialog {
    input = true,
    title = kinds[kind].icon .. " New " .. (kind == "todos" and "todo list" or "note"),
    hints = { { "enter", "create" }, { "esc", "cancel" } },
    on_done = function(title)
      if not title or title == "" then return reopen and reopen() end
      local path = folder(kind) .. "/" .. file_name(title) .. ".md"
      if vim.fn.filereadable(path) == 0 then vim.fn.writefile({ "# " .. title, "", kinds[kind].start }, path) end
      open_popup(path, kind)
    end,
  }
end

local function rename(path, kind, reopen)
  local old = title_of(path)
  dialog {
    input = true, default = old,
    title = "󰏫 Rename",
    hints = { { "enter", "save" }, { "esc", "cancel" } },
    on_done = function(title)
      if title and title ~= "" and title ~= old then
        local lines = vim.fn.readfile(path)
        if lines[1] and lines[1]:match "^#%s" then lines[1] = "# " .. title else table.insert(lines, 1, "# " .. title) end
        close_buffer(path)
        vim.fn.writefile(lines, path)
        local new = folder(kind) .. "/" .. file_name(title) .. ".md"
        -- only upper/lowercase changed is the same file on Windows: renaming still works
        if new ~= path and (new:lower() == path:lower() or vim.fn.filereadable(new) == 0) then
          os.rename(path, new)
        end
      end
      reopen()
    end,
  }
end

local function delete(path, reopen)
  dialog {
    title = "󰆴 Delete", title_hl = "DiagnosticError", border_hl = "DiagnosticError",
    text = 'Delete "' .. title_of(path) .. '"?',
    hints = { { "y", "delete" }, { "n", "keep" } },
    on_done = function(yes)
      if yes then close_buffer(path); os.remove(path) end
      reopen()
    end,
  }
end

function M.pick(kind)
  local pickers, finders, conf = require "telescope.pickers", require "telescope.finders", require("telescope.config").values
  local actions, state = require "telescope.actions", require "telescope.actions.state"
  local k = kinds[kind]

  local items = { { new = true, title = "+ New " .. (kind == "todos" and "todo list" or "note") } }
  local files = vim.fn.glob(folder(kind) .. "/*.md", false, true)
  table.sort(files, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end) -- last edited first
  for _, f in ipairs(files) do
    table.insert(items, { path = vim.fs.normalize(f), title = title_of(f) })
  end

  local function selected()
    local e = state.get_selected_entry()
    return e and e.value
  end
  local function reopen() vim.schedule(function() M.pick(kind) end) end

  pickers.new({}, {
    prompt_title = k.icon .. " " .. k.label,
    results_title = "enter open · ctrl+e rename · ctrl+d delete",
    finder = finders.new_table {
      results = items,
      entry_maker = function(it)
        return { value = it, display = it.new and it.title or ("  " .. it.title), ordinal = it.title, path = it.path }
      end,
    },
    sorter = conf.generic_sorter {},
    -- preview the highlighted file ("+ New" has no file, so it gets a short hint instead)
    previewer = require("telescope.previewers").new_buffer_previewer {
      title = "Preview",
      define_preview = function(self, entry)
        local buf = self.state.bufnr
        if entry.value.new then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Enter: type a title for a new one.", "", "Or type a title above that matches nothing and press Enter." })
          return
        end
        local ok, lines = pcall(vim.fn.readfile, entry.path)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, ok and lines or {})
        vim.bo[buf].filetype = "markdown"
      end,
    },
    attach_mappings = function(bufnr, map)
      actions.select_default:replace(function()
        local it = selected()
        local typed = state.get_current_line()
        actions.close(bufnr)
        if not it or it.new then
          -- "+ New" (or nothing matched): use what was typed as the title, if anything
          if typed ~= "" and not it then
            local path = folder(kind) .. "/" .. file_name(typed) .. ".md"
            if vim.fn.filereadable(path) == 0 then vim.fn.writefile({ "# " .. typed, "", k.start }, path) end
            return open_popup(path, kind)
          end
          return vim.schedule(function() create(kind, reopen) end)
        end
        vim.schedule(function() open_popup(it.path, kind) end)
      end)
      -- open the dialog on top of the picker (which stays visible behind it);
      -- when the dialog is done, the picker closes and reopens with the change
      local function on_item(fn)
        return function()
          local it = selected()
          if not it or it.new then return end
          -- telescope closes itself when its prompt loses focus; keep it open while the dialog shows
          vim.api.nvim_clear_autocmds { group = "PickerInsert", event = "BufLeave", buffer = bufnr }
          vim.cmd "stopinsert"
          vim.schedule(function()
            fn(it, function()
              pcall(actions.close, bufnr)
              reopen()
            end)
          end)
        end
      end
      local ren = on_item(function(it, after) rename(it.path, kind, after) end)
      local del = on_item(function(it, after) delete(it.path, after) end)
      for _, key in ipairs { "<C-e>", "<M-r>" } do map({ "i", "n" }, key, ren) end
      for _, key in ipairs { "<C-d>", "<M-d>" } do map({ "i", "n" }, key, del) end
      return true
    end,
  }):find()
end

-- ---------------------------------------------------------------------------
-- checkmate: boxes in every file of the Notebook folder (and any todo.md elsewhere)
-- ---------------------------------------------------------------------------
M.checkmate = {
  files = { "todo", "TODO", "todo.md", "TODO.md", "*.todo", "*.todo.md", "Notebook/**/*.md" },
  -- keep the real [ ] / [x] in the buffer: render-markdown draws them as □ / ■ and
  -- then doesn't add a bullet in front (it would with checkmate's own symbols)
  todo_states = {
    unchecked = { marker = "[ ]" },
    checked = { marker = "[x]" },
  },
  -- @priority(low / medium / high) colors, muted onedark instead of the bright defaults
  metadata = {
    priority = {
      style = function(ctx)
        local v = ctx.value:lower()
        if v == "high" then return { fg = "#e06c75", bold = true } end
        if v == "medium" then return { fg = "#d19a66" } end
        return { fg = "#61afef" }
      end,
    },
  },
}

M.keys = {
  { "<leader>jt", function() M.pick "todos" end, desc = "Todo lists" },
  { "<leader>jn", function() M.pick "notes" end, desc = "Notes" },
}

return M
