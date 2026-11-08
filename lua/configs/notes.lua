-- Todos + notes in a popup, from anywhere.
-- Both are plain markdown files in one folder. Change the folder here:
local dir = "~/notes"

--   <leader>jt  todo list popup     <leader>jn  notes popup     (same key / q / Esc hides it)
-- Inside them (checkmate.nvim, <leader>T...):
--   <leader>Tn  new todo            <leader>Tt  tick / untick
--   <leader>Ta  move done todos to an "Archive" section at the bottom
--   <leader>Tp / Ts / Td  add @priority / @started / @done
--   Enter in insert mode on a todo line starts the next todo
local M = {}

local function window()
  local ui = { width = vim.o.columns, height = vim.o.lines }
  local w, h = math.floor(ui.width * 0.6), math.floor(ui.height * 0.7)
  return {
    relative = "editor", border = "rounded", title_pos = "center",
    width = w, height = h, row = math.floor((ui.height - h) / 2) - 1, col = math.floor((ui.width - w) / 2),
  }
end

-- q / Esc close the popup. Closing saves the file.
-- (Saved here instead of global-note's autosave: that one skips checkmate on save, which would
--  write ☐/✔ into the file instead of normal markdown [ ] / [x].)
local function post_open(buf, win)
  for _, k in ipairs { "q", "<Esc>" } do
    vim.keymap.set("n", k, function() vim.api.nvim_win_close(win, false) end, { buffer = buf, nowait = true })
  end
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    nested = true, -- let checkmate turn ☐/✔ back into [ ] / [x] while saving
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function() vim.cmd "silent write" end)
      end
    end,
  })
end

M.global_note = {
  directory = dir,
  filename = "todo.md",
  title = " 󰄲 Todo ",
  command_name = "Todo",
  window_config = window,
  post_open = post_open,
  autosave = false, -- saved in post_open above
  additional_presets = {
    notes = { filename = "notes.md", title = " 󰠮 Notes ", command_name = "Notes" },
  },
}

M.checkmate = {
  files = { "todo.md", "notes.md" }, -- checkboxes work in both files
}

M.keys = {
  { "<leader>jt", function() require("global-note").toggle_note() end, desc = "Todo list (popup)" },
  { "<leader>jn", function() require("global-note").toggle_note "notes" end, desc = "Notes (popup)" },
}

return M
