require "nvchad.options"

-- add yours here!

local o = vim.o
o.cursorlineopt = 'both' -- to enable cursorline!
o.relativenumber = true -- Relative number
--
-- Use PowerShell instead of cmd.exe
-- (needs the regular PowerShell install; the Microsoft Store one can't be run by Nvim)
o.shell = vim.fn.executable "pwsh" == 1 and "pwsh" or "powershell"
o.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command"
o.shellquote = ""
o.shellxquote = ""
