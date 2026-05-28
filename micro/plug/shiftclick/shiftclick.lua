VERSION = "0.1.0"

local buffer = import("micro/buffer")

-- micro 2.0.15's built-in MousePress ignores ModShift and always resets the
-- selection at the click point. This handler runs on ShiftMouseLeft instead,
-- extending the selection from the cursor's pre-click position to the click
-- point (the default GUI text-editor behavior)
function shiftClick(bp, te)
  local mx, my = te:Position()
  local click_loc = bp:LocFromVisual(buffer.Loc(mx, my))
  local c = bp.Buf:GetActiveCursor()
  -- anchor the selection at the current cursor position when starting fresh;
  -- if a selection already exists, keep its existing anchor so repeated
  -- shift-clicks grow/shrink from the original point
  if not c:HasSelection() then
    c:SetSelectionStart(c.Loc)
  end
  c:SelectTo(click_loc)
  c:GotoLoc(click_loc)
  bp:Relocate()
  return true
end
