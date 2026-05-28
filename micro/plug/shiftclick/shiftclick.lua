VERSION = "0.1.0"

local buffer = import("micro/buffer")

-- micro 2.0.15's built-in MousePress ignores ModShift and always resets the
-- selection at the click point. This handler runs on ShiftMouseLeft instead,
-- extending the selection from the existing anchor to the click point (the
-- default GUI text-editor behavior)
function shiftClick(bp, te)
  local mx, my = te:Position()
  local click_loc = bp:LocFromVisual(buffer.Loc(mx, my))
  local c = bp.Buf:GetActiveCursor()
  -- Anchor: the end of an existing selection that isn't where the cursor sits
  -- (the cursor lives at the "moving" end), else the cursor's current position
  local anchor
  if c:HasSelection() then
    local s = c.CurSelection[1]
    local e = c.CurSelection[2]
    if c.Loc.X == e.X and c.Loc.Y == e.Y then
      anchor = buffer.Loc(s.X, s.Y)
    else
      anchor = buffer.Loc(e.X, e.Y)
    end
  else
    anchor = buffer.Loc(c.Loc.X, c.Loc.Y)
  end
  if click_loc:GreaterThan(anchor) then
    c:SetSelectionStart(anchor)
    c:SetSelectionEnd(click_loc)
  else
    c:SetSelectionStart(click_loc)
    c:SetSelectionEnd(anchor)
  end
  c:GotoLoc(click_loc)
  bp:Relocate()
  return true
end
