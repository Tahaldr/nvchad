-- Notes + todo list in ~/notes (plain markdown files, also opens in the Obsidian app if you ever want)
-- Keys (all under <leader>j, "journal"):
--   <leader>jn  new note           <leader>jf  find a note by name
--   <leader>js  search inside notes <leader>jd  today's daily note
--   <leader>jt  todo list           <leader>jx  tick / untick the checkbox on this line
-- In a note: Enter on a [[link]] opens it, Enter on a checkbox ticks it.
local M = {}

local notes = vim.fn.expand "~/notes"

M.opts = {
  legacy_commands = false,
  workspaces = { { name = "notes", path = notes } },
  picker = { name = "telescope.nvim" },
  -- name files after the title you type ("Shopping list" -> Shopping list.md)
  note_id_func = function(title)
    if title and title ~= "" then
      return (title:gsub('[\\/:*?"<>|]', ""))
    end
    return os.date "%Y-%m-%d %H%M"
  end,
  new_notes_location = "notes_subdir",
  -- new notes start from ~/notes/templates (edit those files to change how they start)
  templates = { folder = "templates" },
  note = { template = "note.md" },
  daily_notes = { folder = "daily", template = "daily.md" }, -- daily/2026-11-06.md
  frontmatter = { enabled = false }, -- keep notes plain
  footer = { enabled = false },
  ui = { enable = false }, -- render-markdown already draws headings and checkboxes
  checkbox = { order = { " ", "x" } }, -- just todo / done
}

local function obs(cmd)
  return "<cmd>Obsidian " .. cmd .. "<CR>"
end

M.keys = {
  { "<leader>jn", obs "new", desc = "Notes new note" },
  { "<leader>jf", obs "quick_switch", desc = "Notes find note" },
  { "<leader>js", obs "search", desc = "Notes search in notes" },
  { "<leader>jd", obs "today", desc = "Notes today's note" },
  { "<leader>jt", "<cmd>edit " .. notes .. "/todo.md<CR>", desc = "Notes todo list" },
  { "<leader>jx", obs "toggle_checkbox", desc = "Notes toggle checkbox" },
}

return M
