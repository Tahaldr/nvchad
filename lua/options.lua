require "nvchad.options"

-- add yours here!

local o = vim.o
o.cursorlineopt = 'both' -- to enable cursorline!
o.relativenumber = true -- Relative number
--
-- Use PowerShell instead of cmd.exe.
-- pwsh from the Microsoft Store is only a shortcut that Nvim can't run ("'pwsh' is not executable"),
-- and its real folder has spaces in the path (which breaks the NvChad terminal). So find the real
-- folder once and link it as nvim-data\pwsh (no spaces). Looked up again after a PowerShell update.
local function pwsh_path()
  if vim.fn.executable "pwsh" == 1 then return "pwsh" end
  local link = vim.fs.normalize(vim.fn.stdpath "data" .. "/pwsh"):gsub("/", "\\")
  local exe = link .. "\\pwsh.exe"
  if vim.fn.executable(exe) == 1 then return exe end
  local out = vim.fn.system { "cmd", "/c", "pwsh", "-NoLogo", "-NoProfile", "-Command", "Split-Path (Get-Process -Id $PID).Path" }
  local dir = vim.trim(out)
  if vim.v.shell_error == 0 and dir ~= "" then
    pcall(vim.uv.fs_rmdir, link) -- old link (removes only the link, not PowerShell)
    vim.uv.fs_symlink(dir, link, { junction = true })
    if vim.fn.executable(exe) == 1 then return exe end
  end
  return "powershell" -- Windows PowerShell 5.1 as a last resort
end

o.shell = pwsh_path()
o.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command"
o.shellquote = ""
o.shellxquote = ""
