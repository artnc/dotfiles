-- Reflow the comment/paragraph at the cursor at the colorcolumn width, matching VS Code's Rewrap extension behavior
local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local util = import("micro/util")

local PREFIX_PATTERNS = {
  "^(%s*//+%s*)",
  "^(%s*/%*+%s*)",
  "^(%s*%*+%s*)",
  "^(%s*#+%s*)",
  "^(%s*%-%-+%s*)",
  "^(%s*;+%s*)",
  "^(%s*'+%s*)",
  "^(%s*%%+%s*)",
}

local function detect_prefix(line)
  for _, p in ipairs(PREFIX_PATTERNS) do
    local m = line:match(p)
    if m then return m end
  end
end

local function getline(buf, r)
  if r < 0 or r >= buf:LinesNum() then return nil end
  return util.String(buf:LineBytes(r))
end

-- A prefix-only line ends the block (matches VS Code Rewrap's paragraph rule)
local function find_boundary(buf, row, step, prefix)
  while true do
    local line = getline(buf, row + step)
    if line == nil or line:sub(1, #prefix) ~= prefix or #line <= #prefix then
      return row
    end
    row = row + step
  end
end

function rewrapcomment(bp)
  local buf = bp.Buf
  local cur_row = buf:GetActiveCursor().Loc.Y
  local prefix = detect_prefix(getline(buf, cur_row))
  if prefix == nil then
    micro.InfoBar():Error("No comment prefix on this line")
    return
  end
  local start_row = find_boundary(buf, cur_row, -1, prefix)
  local stop_row = find_boundary(buf, cur_row, 1, prefix)

  local words = {}
  local last_line_len
  for r = start_row, stop_row do
    local line = getline(buf, r)
    last_line_len = #line
    for w in line:sub(#prefix + 1):gmatch("%S+") do
      table.insert(words, w)
    end
  end

  local wrap_col = bp.Buf.Settings["colorcolumn"]
  if wrap_col == nil or wrap_col == 0 then wrap_col = 80 end

  local new_lines = {}
  local cur_words = {}
  local cur_len = #prefix
  for _, w in ipairs(words) do
    if #cur_words == 0 then
      cur_words[1] = w
      cur_len = #prefix + #w
    elseif cur_len + 1 + #w > wrap_col then
      table.insert(new_lines, prefix .. table.concat(cur_words, " "))
      cur_words = {w}
      cur_len = #prefix + #w
    else
      table.insert(cur_words, w)
      cur_len = cur_len + 1 + #w
    end
  end
  if #cur_words > 0 then
    table.insert(new_lines, prefix .. table.concat(cur_words, " "))
  end

  buf:Replace(buffer.Loc(0, start_row), buffer.Loc(last_line_len, stop_row), table.concat(new_lines, "\n"))
end

function init()
  config.MakeCommand("rewrapcomment", rewrapcomment, config.NoComplete)
end
