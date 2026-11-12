require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

-- map("n", ";", ":", { desc = "CMD enter command mode" })

-- for switching to Normal Mode
map("i", "jk", "<ESC>")
map("i", "jj", "<ESC>")

-- for exiting terminal
map('t', '<ESC>', [[<C-\><C-n>]], { noremap = true, silent = true })

-- Move lines up/down (Normal mode)
map("n", "<A-j>", ":m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", ":m .-2<CR>==", { desc = "Move line up" })

-- Move selected block up/down (Visual mode)
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move block down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move block up" })

-- Paste with Ctrl+v in normal & insert modes
vim.keymap.set("i", "<C-v>", '<C-r>+', { noremap = true, silent = true })
-- vim.keymap.set("n", "<C-v>", '"+p', { noremap = true, silent = true }) -- its taken by blockWise visual mode

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- Open diagnostic float on current line
map("n", "gl", vim.diagnostic.open_float, { noremap = true, silent = true, desc = "Show line diagnostics" })

-- Esc: clear search highlight + dismiss notifications
map("n", "<Esc>", "<cmd>noh<CR><cmd>Noice dismiss<CR>", { desc = "Clear highlight & dismiss notifications" })


-- Lspsaga
map("n", "gp", "<cmd>Lspsaga peek_definition<CR>", { desc = "Peek definition" })
map("n", "<leader>o", "<cmd>Lspsaga outline<CR>", { desc = "File outline" })

-- Run the current file in a floating terminal (reuses the same window on each run)
-- Which program runs each file type (to add a language: filetype = "program")
local runners = {
  python = "python",
  javascript = "node",
}

map("n", "<leader>rr", function()
  local program = runners[vim.bo.filetype]
  if not program then
    vim.notify("No runner for filetype: " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end
  vim.cmd "w" -- save the file first
  require("nvchad.term").runner {
    id = "runner",
    -- Terminal style: replace "float" below with one of these
    --   "float" = pop-up window in the middle of the screen
    --   "sp"    = split at the bottom (code stays visible above)
    --   "vsp"   = split on the right side (code stays visible on the left)
    pos = "float",
    cmd = function()
      return program .. " " .. vim.fn.shellescape(vim.fn.expand "%:p") -- e.g. node "C:\...\file.js"
    end,
  }
end, { desc = "Run current file (Python / JS)" })
