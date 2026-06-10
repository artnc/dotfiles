-- Highlight every occurrence of the identifier under the cursor (or of the
-- current selection), like VSCode/Sublime. micro has no built-in word-occurrence
-- highlight, but its search highlighter already paints all matches of
-- `Buf.LastSearch` whenever `Buf.HighlightSearch` is set (see the display gate
-- in bufwindow.go and LineArray.SearchMatch). So on every event we just point
-- that machinery at the word under the cursor.
--
-- LineArray.SearchMatch caches matches keyed on (LastSearch, LastSearchRegex,
-- ignorecase) and auto-rescans when any of those change, so re-setting the same
-- term each event is free and a changed term re-highlights with no extra call.
-- This co-opts the normal Find highlight: while a word is under the cursor the
-- `hlsearch` color tracks it, and the manual-search highlight (and Esc to clear
-- it) no longer persists
local micro = import("micro")
local util = import("micro/util")
local regexp = import("regexp")

-- True if char index `i` of the active cursor's line is a word char. Bounded by
-- `n` (the line's char count) so RuneUnder is never called out of range: it
-- clamps negatives to 0 and returns '\n' past the end, either of which would
-- corrupt the boundary scan below
local function is_word_char(cur, i, n)
  if i < 0 or i >= n then
    return false
  end
  return util.IsWordChar(util.RuneStr(cur:RuneUnder(i)))
end

-- The contiguous run of word chars touching the cursor, as a string, or nil if
-- the cursor isn't on a word. Prefer the char at the cursor; fall back to the
-- char just left of it so a cursor resting at a word's right edge still counts
local function word_under_cursor(cur, n)
  local x = cur.Loc.X
  local lo
  if is_word_char(cur, x, n) then
    lo = x
  elseif is_word_char(cur, x - 1, n) then
    lo = x - 1
  else
    return nil
  end
  local hi = lo
  while is_word_char(cur, lo - 1, n) do
    lo = lo - 1
  end
  while is_word_char(cur, hi + 1, n) do
    hi = hi + 1
  end
  local runes = {}
  for i = lo, hi do
    runes[#runes + 1] = util.RuneStr(cur:RuneUnder(i))
  end
  return table.concat(runes)
end

local function highlight(buf, term, use_regex)
  buf.LastSearch = term
  buf.LastSearchRegex = use_regex
  buf.HighlightSearch = true
end

-- micro runs this after literally every event, which is the only hook that fires
-- on every cursor move (there's no dedicated cursor-moved callback)
function onAnyEvent()
  local bp = micro.CurPane()
  if bp == nil then
    return
  end
  local buf = bp.Buf
  local cur = buf:GetActiveCursor()

  -- A single-line selection highlights its exact text verbatim, matching VSCode.
  -- Multi-line selections can't be expressed as one search term, so clear
  if cur:HasSelection() then
    local sel = util.String(cur:GetSelection())
    if sel ~= "" and not sel:find("\n", 1, true) then
      highlight(buf, sel, false)
    else
      buf.HighlightSearch = false
    end
    return
  end

  -- No selection: whole-word match the word under the cursor via \b...\b, with
  -- the word regex-escaped in case it contains metacharacters
  local word = word_under_cursor(cur, util.CharacterCountInString(buf:Line(cur.Loc.Y)))
  if word == nil then
    buf.HighlightSearch = false
    return
  end
  highlight(buf, "\\b" .. regexp.QuoteMeta(word) .. "\\b", true)
end
