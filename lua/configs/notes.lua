-- Todo lists + notes in a popup, from anywhere. Plain markdown files, checkmate draws the boxes.
-- Everything lives in one folder. Change it here:
local root = "~/Documents/Notebook"

--   <leader>jt  pick a todo list      <leader>jn  pick a note
--   In the picker:  enter open   "+ New" entry makes one (asks for a title)
--                   ctrl+e rename   ctrl+d delete
--   In the popup (keys shown in its bottom border):
--     enter tick / untick   o new todo   s new sub-todo   tab fold / unfold sub-todos
--     > / < indent / outdent   q / Esc close (saves)
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
-- helpers for the hint line in the popup border
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

-- ask in the command line; nil when cancelled with Esc
local function ask(prompt, default)
  local ok, v = pcall(vim.fn.input, { prompt = prompt, default = default or "", cancelreturn = "" })
  vim.cmd "redraw"
  if not ok or v == "" then return nil end
  return vim.trim(v)
end

-- ---------------------------------------------------------------------------
-- popup
-- ---------------------------------------------------------------------------
local function is_todo(line)
  return line:match "^%s*[-*+] %[[ xX]%]"
end

local function indent_of(line) return #line:match "^%s*" end
local function blank(line) return line:match "^%s*$" ~= nil end

-- last line of the todo on row r plus all its sub-todos (anything indented deeper below it)
local function subtree_end(buf, r)
  local lines = vim.api.nvim_buf_get_lines(buf, r - 1, -1, false)
  local base, last = indent_of(lines[1]), r
  for i = 2, #lines do
    if not blank(lines[i]) then
      if indent_of(lines[i]) <= base then break end
      last = r + i - 1
    end
  end
  return last
end

-- add a todo after the one under the cursor (after its sub-todos too), sub = one level deeper
local function add_todo(buf, sub)
  local r = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  if not is_todo(line) then return vim.api.nvim_feedkeys("o- [ ] ", "n", false) end
  local last = subtree_end(buf, r)
  local ind = indent_of(line)
  if sub then
    -- line up with existing sub-todos, else 2 spaces deeper
    local next_line = last > r and vim.api.nvim_buf_get_lines(buf, r, r + 1, false)[1]
    ind = next_line and indent_of(next_line) or ind + 2
    if vim.fn.foldclosed(r + 1) ~= -1 then vim.cmd((r + 1) .. "foldopen!") end
  end
  vim.api.nvim_buf_set_lines(buf, last, last, false, { string.rep(" ", ind) .. "- [ ] " })
  vim.api.nvim_win_set_cursor(0, { last + 1, 0 })
  vim.cmd "startinsert!"
end

-- Tab: on a todo with sub-todos, fold / unfold them; on a sub-todo, fold it into its parent
local function toggle_fold(buf)
  local r = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  if subtree_end(buf, r) > r then
    if vim.fn.foldclosed(r + 1) ~= -1 then vim.cmd((r + 1) .. "foldopen") else vim.cmd((r + 1) .. "foldclose") end
  elseif indent_of(line) > 0 and vim.fn.foldlevel(r) > 0 then
    vim.cmd "foldclose"
    vim.api.nvim_win_set_cursor(0, { math.max(1, vim.fn.foldclosed(r) - 1), 0 })
  end
end

-- what a folded group shows: "  󰅂 3 sub-todos"
function M.foldtext()
  local first = vim.fn.getline(vim.v.foldstart)
  local n = 0
  for l = vim.v.foldstart, vim.v.foldend do
    if is_todo(vim.fn.getline(l)) then n = n + 1 end
  end
  return string.rep(" ", indent_of(first)) .. "󰅂 " .. n .. " sub-todo" .. (n == 1 and "" or "s")
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
    { "enter", "tick" }, { "o", "new" }, { "s", "sub-todo" }, { "tab", "fold" }, { "<leader>Tp", "priority" }, { "<leader>Ta", "archive" }, { "q", "close" },
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
  -- sub-todos are indented 2 spaces; fold by indent so each parent can collapse its sub-todos
  vim.bo[buf].shiftwidth, vim.bo[buf].expandtab = 2, true
  local function folds()
    if not vim.api.nvim_win_is_valid(win) then return end
    local wo = vim.wo[win]
    wo.foldmethod, wo.foldenable, wo.foldlevel = "indent", true, 99
    wo.foldtext = "v:lua.require'configs.notes'.foldtext()"
    wo.fillchars = "fold: "
  end
  folds()
  vim.schedule(folds) -- again after filetype plugins have had their say
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
  -- o: new todo at the same level, s: new sub-todo under the one at the cursor
  vim.keymap.set("n", "o", function() add_todo(buf, false) end, opts "New todo")
  vim.keymap.set("n", "s", function() add_todo(buf, true) end, opts "New sub-todo")
  -- Tab folds / unfolds sub-todos, Shift-Tab folds / unfolds all of them
  vim.keymap.set("n", "<Tab>", function() toggle_fold(buf) end, opts "Fold sub-todos")
  vim.keymap.set("n", "<S-Tab>", function()
    vim.wo.foldlevel = vim.wo.foldlevel > 0 and 0 or 99
  end, opts "Fold / unfold all")
  -- > / < turn a todo into a sub-todo of the one above, or back (with its own sub-todos)
  vim.keymap.set("n", ">", function()
    local r = vim.api.nvim_win_get_cursor(0)[1]
    vim.cmd(r .. "," .. subtree_end(buf, r) .. ">")
  end, opts "Indent todo")
  vim.keymap.set("n", "<", function()
    local r = vim.api.nvim_win_get_cursor(0)[1]
    vim.cmd(r .. "," .. subtree_end(buf, r) .. "<")
  end, opts "Outdent todo")
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

local function create(kind)
  local title = ask(kinds[kind].icon .. " New " .. (kind == "todos" and "todo list" or "note") .. " title: ")
  if not title or title == "" then return end
  local path = folder(kind) .. "/" .. file_name(title) .. ".md"
  if vim.fn.filereadable(path) == 0 then vim.fn.writefile({ "# " .. title, "", kinds[kind].start }, path) end
  open_popup(path, kind)
end

local function rename(path, kind)
  local old = title_of(path)
  local title = ask("󰏫 Rename: ", old)
  if not title or title == "" or title == old then return end
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

local function delete(path)
  local answer = ask('󰆴 Delete "' .. title_of(path) .. '"? (y/n) ')
  if answer and answer:lower():sub(1, 1) == "y" then
    close_buffer(path)
    os.remove(path)
  end
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
          return vim.schedule(function() create(kind) end)
        end
        vim.schedule(function() open_popup(it.path, kind) end)
      end)
      -- ask in the command line while the picker stays open, then refresh the list
      local function on_item(fn)
        return function()
          local it = selected()
          if not it or it.new then return end
          fn(it)
          actions.close(bufnr)
          reopen()
        end
      end
      local ren = on_item(function(it) rename(it.path, kind) end)
      local del = on_item(function(it) delete(it.path) end)
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
  -- @priority(low / medium / high) colors, muted onedark instead of the bright defaults.
  -- Overriding a tag replaces checkmate's whole default for it, so key / choices must be here too.
  metadata = {
    priority = {
      style = function(ctx)
        local v = ctx.value:lower()
        if v == "high" then return { fg = "#e06c75", bold = true } end
        if v == "medium" then return { fg = "#d19a66" } end
        return { fg = "#61afef" }
      end,
      get_value = function() return "medium" end,
      choices = function() return { "low", "medium", "high" } end,
      key = "<leader>Tp",
      sort_order = 10,
      jump_to_on_insert = "value",
      select_on_insert = true,
    },
  },
}

M.keys = {
  { "<leader>jt", function() M.pick "todos" end, desc = "Todo lists" },
  { "<leader>jn", function() M.pick "notes" end, desc = "Notes" },
}

return M
