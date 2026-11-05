require "nvchad.options"

-- add yours here!

local o = vim.o
o.cursorlineopt = 'both' -- to enable cursorline!
o.relativenumber = true -- Relative number
--
-- Use PowerShell instead of cmd.exe.
-- pwsh from the Microsoft Store is only a shortcut that Nvim can't run ("'pwsh' is not executable"),
-- so find the real pwsh.exe once and remember it (looked up again after a PowerShell update).
local function pwsh_path()
  if vim.fn.executable "pwsh" == 1 then return "pwsh" end
  local cache = vim.fn.stdpath "data" .. "/pwsh-path.txt"
  local ok, lines = pcall(vim.fn.readfile, cache)
  if ok and lines[1] and vim.fn.executable(lines[1]) == 1 then return lines[1] end
  local out = vim.fn.system { "cmd", "/c", "pwsh", "-NoLogo", "-NoProfile", "-Command", "(Get-Process -Id $PID).Path" }
  local path = vim.trim(out)
  if vim.v.shell_error == 0 and vim.fn.executable(path) == 1 then
    vim.fn.writefile({ path }, cache)
    return path
  end
  return "powershell" -- Windows PowerShell 5.1 as a last resort
end

local shell = pwsh_path()
o.shell = shell:find " " and ('"' .. shell .. '"') or shell -- quote paths with spaces
o.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command"
o.shellquote = ""
o.shellxquote = ""
