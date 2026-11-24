-- Undo like VS Code: while typing, every new word (or a pause of 1s) starts a new undo step,
-- so `u` takes back one word at a time instead of everything since you entered insert mode.

local last, at, refed = nil, 0, false -- last char kind ("word"/"gap"), when it was typed

vim.api.nvim_create_autocmd("InsertEnter", {
  callback = function()
    last, at = nil, 0
  end,
})

vim.api.nvim_create_autocmd("InsertCharPre", {
  callback = function()
    local ch, now = vim.v.char, vim.uv.now()
    local kind = ch:match "^[%s%p]$" and "gap" or "word" -- any letter (Arabic too) is "word"
    local split = not refed
      and kind == "word"
      and last ~= nil
      and (last == "gap" or now - at > 1000)
      and vim.bo.buftype ~= "prompt"
      and vim.fn.reg_executing() == "" -- leave macros alone
    refed, last, at = false, kind, now
    if split then
      -- drop the char, then type "close undo step" + the char again, ahead of anything else
      refed = true
      vim.v.char = ""
      vim.api.nvim_feedkeys(vim.keycode "<C-g>u" .. ch, "in", false)
    end
  end,
})
