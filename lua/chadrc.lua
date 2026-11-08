-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

-- ---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "onedark",
  transparency = true,

  theme_toggle = { "onedark", "one_light" },

  hl_override = {
    Comment = { italic = true },
    ["@comment"] = { italic = true },
  },
}

M.nvdash = {
  load_on_startup = true,

  header = {
    " ██▓    ▄▄▄      ▒███████▒ ██▓",
    "▓██▒   ▒████▄    ▒ ▒ ▒ ▄▀░▓██▒",
    "▒██░   ▒██  ▀█▄  ░ ▒ ▄▀▒░ ▒██▒",
    "▒██░   ░██▄▄▄▄██   ▄▀▒   ░░██░",
    "░██████▒▓█   ▓██▒▒███████▒░██░",
    "░ ▒░▓  ░▒▒   ▓▒█░░▒▒ ▓░▒░▒░▓  ",
    "░ ░ ▒  ░ ▒   ▒▒ ░░░▒ ▒ ░ ▒ ▒ ░",
    "  ░ ░    ░   ▒   ░ ░ ░ ░ ░ ▒ ░",
    "    ░  ░     ░  ░  ░ ░     ░  ",
    "                 ░            ",
    "                              ",
    "                              ",
    "                              ",
  },

  buttons = {
    { txt = "  Find File", keys = "ff", cmd = "Telescope find_files" },
    { txt = "  Recent Files", keys = "fo", cmd = "Telescope oldfiles" },
    { txt = "󰈭  Find Word", keys = "fw", cmd = "Telescope live_grep" },
    { txt = "󰄲  Todo", keys = "jt", cmd = "Todo" },
    { txt = "󱥚  Themes", keys = "th", cmd = ":lua require('nvchad.themes').open()" },
    { txt = "  Mappings", keys = "ch", cmd = "NvCheatsheet" },
  },
}
M.ui = {
  tabufline = {
    enabled = true,
    lazyload = true,
    order = { "treeOffset", "buffers", "tabs", "btns" },
    modules = nil,
    bufwidth = 21,
  },

  statusline = {
    theme = "vscode_colored",
    separator_style = "arrow",
  },

  telescope = { style = "bordered" },

  colorify = {
    enabled = true,
    mode = "virtual", -- fg, bg, virtual
    virt_text = "󱓻 ",
    highlight = { hex = true, lspvars = true },
  },
}

return M
