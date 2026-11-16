require "nvchad.autocmds"

-- Close leftover noice popups (signature help / hover) when leaving insert mode,
-- so pressing Esc never leaves an empty box stuck on screen
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local is_float = vim.api.nvim_win_get_config(win).relative ~= ""
        local buf = vim.api.nvim_win_get_buf(win)
        if is_float and vim.bo[buf].filetype == "noice" then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
    end)
  end,
})
