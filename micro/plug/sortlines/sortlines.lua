-- Sort the lines spanned by the selection by raw byte order (case-sensitive, so
-- uppercase sorts before lowercase). Whole lines are sorted even if the
-- selection starts or ends mid-line
local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local util = import("micro/util")

function sortlines(bp)
  local buf = bp.Buf
  local cur = buf:GetActiveCursor()
  if not cur:HasSelection() then
    micro.InfoBar():Error("Select lines to sort first")
    return
  end

  -- Order the endpoints by row since the anchor may sit below the cursor when
  -- selecting upward. Only rows matter here, so a column tiebreak isn't needed:
  -- on a single-row selection the range is one line regardless
  local top = cur.CurSelection[1]
  local bot = cur.CurSelection[2]
  if top.Y > bot.Y then
    top, bot = bot, top
  end
  local start_row = top.Y
  local stop_row = bot.Y
  -- A selection ending at column 0 of a line (dragged onto the next line) doesn't
  -- include that line, matching VSCode's behavior
  if stop_row > start_row and bot.X == 0 then
    stop_row = stop_row - 1
  end

  -- Collect the full lines in range, tracking the last line's length for Replace
  local lines = {}
  local last_line_len
  for r = start_row, stop_row do
    local line = util.String(buf:LineBytes(r))
    last_line_len = #line
    lines[#lines + 1] = line
  end

  -- Sort by raw byte order so it's case-sensitive: uppercase (ASCII 65-90) sorts
  -- before lowercase (97-122), e.g. "B" before "a"
  table.sort(lines)

  buf:Replace(buffer.Loc(0, start_row), buffer.Loc(last_line_len, stop_row), table.concat(lines, "\n"))
end

function init()
  config.MakeCommand("sortlines", sortlines, config.NoComplete)
end
