-- Todo lists + notes in a popup, from anywhere. Plain markdown files, checkmate draws the boxes.
-- Everything lives in one folder. Change it here:
local root = "~/Documents/Coding/Notebook"

--   <leader>jt  pick a todo list      <leader>jn  pick a note
--   In the picker:  enter open   "+ New" entry makes one (asks for a title)
--                   alt+r rename  alt+d delete
--   In the popup:   q / Esc close (saves)
--   Todos (checkmate, <leader>T...):  <leader>Tn new todo   <leader>Tt tick / untick
--     <leader>Ta archive done ones   <leader>Tp / Ts / Td  @priority / @started / @done
--     Enter while typing a todo starts the next one
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
-- popup
-- ---------------------------------------------------------------------------
local function open_popup(path, kind)
  -- already open: just jump to it
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.w[w].notebook and vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))) == path then
      return vim.api.nvim_set_current_win(w)
    end
  end
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.bo[buf].buflisted = false
  local W, H = vim.o.columns, vim.o.lines
  local w, h = math.floor(W * 0.6), math.floor(H * 0.7)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", border = "rounded", title_pos = "center",
    title = " " .. kinds[kind].icon .. " " .. title_of(path) .. " ",
    width = w, height = h, row = math.floor((H - h) / 2) - 1, col = math.floor((W - w) / 2),
  })
  vim.w[win].notebook = true
  for _, k in ipairs { "q", "<Esc>" } do
    vim.keymap.set("n", k, function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, false) end
    end, { buffer = buf, nowait = true, desc = "Close popup" })
  end
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
-- picker
-- ---------------------------------------------------------------------------
local function create(kind)
  vim.ui.input({ prompt = "New " .. (kind == "todos" and "todo list" or "note") .. " title: " }, function(title)
    if not title or vim.trim(title) == "" then return end
    title = vim.trim(title)
    local path = folder(kind) .. "/" .. file_name(title) .. ".md"
    if vim.fn.filereadable(path) == 0 then
      vim.fn.writefile({ "# " .. title, "", kinds[kind].start }, path)
    end
    open_popup(path, kind)
  end)
end

local function rename(path, kind, reopen)
  vim.ui.input({ prompt = "New title: ", default = title_of(path) }, function(title)
    if not title or vim.trim(title) == "" then return reopen() end
    title = vim.trim(title)
    local lines = vim.fn.readfile(path)
    if lines[1] and lines[1]:match "^#%s" then lines[1] = "# " .. title else table.insert(lines, 1, "# " .. title) end
    local new = folder(kind) .. "/" .. file_name(title) .. ".md"
    vim.fn.writefile(lines, new)
    if new ~= path then
      local b = vim.fn.bufnr(path)
      if b ~= -1 then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
      os.remove(path)
    end
    reopen()
  end)
end

local function delete(path, reopen)
  vim.ui.select({ "No", "Yes, delete it" }, { prompt = "Delete \"" .. title_of(path) .. "\"?" }, function(choice)
    if choice == "Yes, delete it" then
      local b = vim.fn.bufnr(path)
      if b ~= -1 then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
      os.remove(path)
    end
    reopen()
  end)
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
    results_title = "enter open · alt+r rename · alt+d delete",
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
          return create(kind)
        end
        open_popup(it.path, kind)
      end)
      map({ "i", "n" }, "<M-r>", function()
        local it = selected()
        if not it or it.new then return end
        actions.close(bufnr); rename(it.path, kind, reopen)
      end)
      map({ "i", "n" }, "<M-d>", function()
        local it = selected()
        if not it or it.new then return end
        actions.close(bufnr); delete(it.path, reopen)
      end)
      return true
    end,
  }):find()
end

-- ---------------------------------------------------------------------------
-- checkmate: boxes in every file of the Notebook folder (and any todo.md elsewhere)
-- ---------------------------------------------------------------------------
M.checkmate = {
  files = { "todo", "TODO", "todo.md", "TODO.md", "*.todo", "*.todo.md", "Notebook/**/*.md" },
  todo_states = {
    unchecked = { marker = "□" },
    checked = { marker = "■" },
  },
}

M.keys = {
  { "<leader>jt", function() M.pick "todos" end, desc = "Todo lists" },
  { "<leader>jn", function() M.pick "notes" end, desc = "Notes" },
}

return M
