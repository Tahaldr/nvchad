-- Arabic / Hebrew display for terminals without BiDi (Windows Terminal, herdr).
--
-- The terminal draws every line left to right, so Arabic shows reversed and
-- unjoined. This draws each right-to-left run of a line over itself, shaped into
-- Arabic presentation forms and in visual order. The buffer text is untouched
-- (it's only a display overlay), and the line under the cursor in insert mode is
-- left as-is so editing stays predictable.
--
-- Same algorithm as the cliamp RTL fix. Toggle with :ArabicToggle.

local M = { enabled = true }
local api = vim.api
local ns = api.nvim_create_namespace "arabic_rtl"

-- presentation forms: isolated, final, initial, medial (0 = none)
local forms = {
  [0x0621] = { 0xFE80, 0, 0, 0 }, [0x0622] = { 0xFE81, 0xFE82, 0, 0 }, [0x0623] = { 0xFE83, 0xFE84, 0, 0 },
  [0x0624] = { 0xFE85, 0xFE86, 0, 0 }, [0x0625] = { 0xFE87, 0xFE88, 0, 0 }, [0x0626] = { 0xFE89, 0xFE8A, 0xFE8B, 0xFE8C },
  [0x0627] = { 0xFE8D, 0xFE8E, 0, 0 }, [0x0628] = { 0xFE8F, 0xFE90, 0xFE91, 0xFE92 }, [0x0629] = { 0xFE93, 0xFE94, 0, 0 },
  [0x062A] = { 0xFE95, 0xFE96, 0xFE97, 0xFE98 }, [0x062B] = { 0xFE99, 0xFE9A, 0xFE9B, 0xFE9C },
  [0x062C] = { 0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0 }, [0x062D] = { 0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4 },
  [0x062E] = { 0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8 }, [0x062F] = { 0xFEA9, 0xFEAA, 0, 0 }, [0x0630] = { 0xFEAB, 0xFEAC, 0, 0 },
  [0x0631] = { 0xFEAD, 0xFEAE, 0, 0 }, [0x0632] = { 0xFEAF, 0xFEB0, 0, 0 }, [0x0633] = { 0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4 },
  [0x0634] = { 0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8 }, [0x0635] = { 0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC },
  [0x0636] = { 0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0 }, [0x0637] = { 0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4 },
  [0x0638] = { 0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8 }, [0x0639] = { 0xFEC9, 0xFECA, 0xFECB, 0xFECC },
  [0x063A] = { 0xFECD, 0xFECE, 0xFECF, 0xFED0 }, [0x0641] = { 0xFED1, 0xFED2, 0xFED3, 0xFED4 },
  [0x0642] = { 0xFED5, 0xFED6, 0xFED7, 0xFED8 }, [0x0643] = { 0xFED9, 0xFEDA, 0xFEDB, 0xFEDC },
  [0x0644] = { 0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0 }, [0x0645] = { 0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4 },
  [0x0646] = { 0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8 }, [0x0647] = { 0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC },
  [0x0648] = { 0xFEED, 0xFEEE, 0, 0 }, [0x0649] = { 0xFEEF, 0xFEF0, 0xFBE8, 0xFBE9 },
  [0x064A] = { 0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4 }, [0x0671] = { 0xFB50, 0xFB51, 0, 0 },
  [0x067E] = { 0xFB56, 0xFB57, 0xFB58, 0xFB59 }, [0x0686] = { 0xFB7A, 0xFB7B, 0xFB7C, 0xFB7D },
  [0x0698] = { 0xFB8A, 0xFB8B, 0, 0 }, [0x06A4] = { 0xFB6A, 0xFB6B, 0xFB6C, 0xFB6D },
  [0x06A9] = { 0xFB8E, 0xFB8F, 0xFB90, 0xFB91 }, [0x06AF] = { 0xFB92, 0xFB93, 0xFB94, 0xFB95 },
  [0x06CC] = { 0xFBFC, 0xFBFD, 0xFBFE, 0xFBFF },
}
local TATWEEL, ZWJ = 0x0640, 0x200D

local function is_mark(c) -- combining marks (harakat, Hebrew points): no cell of their own
  return (c >= 0x0591 and c <= 0x05BD) or c == 0x05BF or (c >= 0x05C1 and c <= 0x05C7)
    or (c >= 0x0610 and c <= 0x061A) or (c >= 0x064B and c <= 0x065F) or c == 0x0670
    or (c >= 0x06D6 and c <= 0x06DC) or (c >= 0x06DF and c <= 0x06E4) or c == 0x06E7 or c == 0x06E8
    or (c >= 0x06EA and c <= 0x06ED) or (c >= 0x08D3 and c <= 0x08FF) or (c >= 0x0300 and c <= 0x036F)
end
local function is_arabic_digit(c) return (c >= 0x0660 and c <= 0x0669) or (c >= 0x06F0 and c <= 0x06F9) end
local function is_rtl(c)
  if c >= 0x0590 and c <= 0x08FF then return not is_mark(c) and not is_arabic_digit(c) end
  return (c >= 0xFB1D and c <= 0xFDFF) or (c >= 0xFE70 and c <= 0xFEFF)
end
local function is_ltr_letter(c)
  return (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) or (c >= 0xC0 and c < 0x0590 and not is_mark(c))
end
local function is_ltr_strong(c) return is_ltr_letter(c) or (c >= 0x30 and c <= 0x39) or is_arabic_digit(c) end
local function joins_next(c)
  if c == TATWEEL or c == ZWJ then return true end
  local f = forms[c]
  return f ~= nil and f[3] ~= 0
end
local function joins_prev(c) return c == TATWEEL or c == ZWJ or forms[c] ~= nil end

local function shape(rs)
  local out = {}
  for i, c in ipairs(rs) do
    local f = forms[c]
    if not f then
      out[i] = c
    else
      local p, n = 0, 0
      for j = i - 1, 1, -1 do if not is_mark(rs[j]) then p = rs[j]; break end end
      for j = i + 1, #rs do if not is_mark(rs[j]) then n = rs[j]; break end end
      local jp = p ~= 0 and joins_next(p)
      local jn = f[3] ~= 0 and n ~= 0 and joins_prev(n)
      local g = 0
      if jp and jn then g = f[4] elseif jp then g = f[2] elseif jn then g = f[3] end
      if g == 0 then g = f[1] end
      out[i] = g ~= 0 and g or c
    end
  end
  return out
end

local mirror = { [0x28] = 0x29, [0x29] = 0x28, [0x5B] = 0x5D, [0x5D] = 0x5B, [0x7B] = 0x7D, [0x7D] = 0x7B,
  [0x3C] = 0x3E, [0x3E] = 0x3C, [0xAB] = 0xBB, [0xBB] = 0xAB }
local inner = { [0x2E] = true, [0x2C] = true, [0x3A] = true, [0x2F] = true, [0x2D] = true, [0x27] = true }

local function reverse_run(rs)
  local clusters, i = {}, 1
  while i <= #rs do
    local j = i + 1
    if is_ltr_strong(rs[i]) then
      while j <= #rs and (is_ltr_strong(rs[j]) or is_mark(rs[j])
        or (inner[rs[j]] and j + 1 <= #rs and is_ltr_strong(rs[j + 1]))) do j = j + 1 end
    else
      while j <= #rs and is_mark(rs[j]) do j = j + 1 end
    end
    clusters[#clusters + 1] = { i, j - 1 }
    i = j
  end
  local out = {}
  for k = #clusters, 1, -1 do
    local a, b = clusters[k][1], clusters[k][2]
    if a == b and mirror[rs[a]] then
      out[#out + 1] = mirror[rs[a]]
    else
      for x = a, b do out[#out + 1] = rs[x] end
    end
  end
  return out
end

local function utf8_char(c)
  if c < 0x80 then return string.char(c) end
  if c < 0x800 then return string.char(0xC0 + math.floor(c / 64), 0x80 + c % 64) end
  if c < 0x10000 then return string.char(0xE0 + math.floor(c / 4096), 0x80 + math.floor(c / 64) % 64, 0x80 + c % 64) end
  return string.char(0xF0 + math.floor(c / 262144), 0x80 + math.floor(c / 4096) % 64, 0x80 + math.floor(c / 64) % 64, 0x80 + c % 64)
end

-- decode a line into code points and their byte offsets
local function decode(s)
  local cps, pos, i, n = {}, {}, 1, #s
  while i <= n do
    local b = s:byte(i)
    local c, len
    if b < 0x80 then c, len = b, 1
    elseif b >= 0xF0 then c, len = (b % 8) * 262144 + (s:byte(i + 1) % 64) * 4096 + (s:byte(i + 2) % 64) * 64 + s:byte(i + 3) % 64, 4
    elseif b >= 0xE0 then c, len = (b % 16) * 4096 + (s:byte(i + 1) % 64) * 64 + s:byte(i + 2) % 64, 3
    elseif b >= 0xC0 then c, len = (b % 32) * 64 + s:byte(i + 1) % 64, 2
    else c, len = b, 1 end
    cps[#cps + 1] = c or 0xFFFD
    pos[#pos + 1] = i - 1
    i = i + len
  end
  return cps, pos
end

-- RTL runs of a line: { col = start byte, stop = end byte, text = visual text } (cached by line content)
local cache = {}
local cache_n = 0
function M.runs(line)
  local hit = cache[line]
  if hit then return hit end
  local cps, pos = decode(line)
  local runs, i = {}, 1
  while i <= #cps do
    if not is_rtl(cps[i]) then
      i = i + 1
    else
      local last = i
      for j = i + 1, #cps do
        if is_rtl(cps[j]) then last = j elseif is_ltr_letter(cps[j]) then break end
      end
      local e = last
      while e + 1 <= #cps and is_mark(cps[e + 1]) do e = e + 1 end
      local run = {}
      for x = i, e do run[#run + 1] = cps[x] end
      local vis = reverse_run(shape(run))
      local parts = {}
      for x = 1, #vis do parts[x] = utf8_char(vis[x]) end
      runs[#runs + 1] = { col = pos[i], stop = pos[e + 1] or #line, text = table.concat(parts) }
      i = e + 1
    end
  end
  cache_n = cache_n + 1
  if cache_n > 2000 then cache = {}; cache_n = 0 end
  cache[line] = runs
  return runs
end

-- the whole line in visual order (handy for testing)
function M.visual(line)
  local out, last = {}, 0
  for _, r in ipairs(M.runs(line)) do
    out[#out + 1] = line:sub(last + 1, r.col)
    out[#out + 1] = r.text
    last = r.stop
  end
  out[#out + 1] = line:sub(last + 1)
  return table.concat(out)
end

-- highlight under a position (so Arabic in comments/strings keeps its color)
local hl_cache = {}
local function hl_at(buf, row, col)
  local key = buf .. ":" .. api.nvim_buf_get_changedtick(buf) .. ":" .. row .. ":" .. col
  local v = hl_cache[key]
  if v ~= nil then return v or nil end
  local ok, info = pcall(vim.inspect_pos, buf, row, col, { extmarks = false, semantic_tokens = true, syntax = true, treesitter = true })
  local hl = false
  if ok and info then
    local list = (#info.semantic_tokens > 0 and info.semantic_tokens) or (#info.treesitter > 0 and info.treesitter) or info.syntax
    local last = list and list[#list]
    if last then hl = last.hl_group_link or last.hl_group or (last.opts and last.opts.hl_group) or false end
  end
  if vim.tbl_count(hl_cache) > 5000 then hl_cache = {} end
  hl_cache[key] = hl
  return hl or nil
end

api.nvim_set_decoration_provider(ns, {
  on_win = function(_, _, buf)
    return M.enabled and vim.bo[buf].buftype ~= "terminal"
  end,
  on_line = function(_, win, buf, row)
    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    -- quick byte check: Hebrew/Arabic code points start with UTF-8 bytes D6-DF or EF (presentation forms)
    if not line or not line:find "[\214-\223\239]" then return end
    if api.nvim_get_mode().mode:sub(1, 1) == "i" and api.nvim_win_get_cursor(win)[1] - 1 == row then return end
    for _, r in ipairs(M.runs(line)) do
      local hl = hl_at(buf, row, r.col)
      pcall(api.nvim_buf_set_extmark, buf, ns, row, r.col, {
        virt_text = { { r.text, hl or "Normal" } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
        ephemeral = true,
      })
    end
  end,
})

-- the cursor line switches between overlay and real text when entering/leaving insert mode
api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
  group = api.nvim_create_augroup("ArabicRtl", { clear = true }),
  callback = function() vim.cmd "redraw!" end,
})

api.nvim_create_user_command("ArabicToggle", function()
  M.enabled = not M.enabled
  vim.cmd "redraw!"
  vim.notify("Arabic display " .. (M.enabled and "on" or "off"))
end, { desc = "Toggle Arabic/Hebrew right-to-left display" })

return M
