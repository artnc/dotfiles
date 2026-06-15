-- Make the scrollbar draggable and clickable, like a GUI editor. micro draws a
-- scrollbar (the `scrollbar` setting) but has no built-in way to interact with
-- it: a click in the scrollbar column just falls through to MousePress and moves
-- the cursor. So we intercept MouseLeft/MouseLeftDrag/MouseLeftRelease and act on
-- the scrollbar column ourselves, scrolling the viewport (cursor stays put)
-- instead of moving the cursor:
--   - Grabbing the thumb scrolls so its top tracks the mouse, preserving the
--     grab offset, so the thumb stays put on mouse-down and only moves with the
--     drag (it never jumps to center on the click)
--   - A click on the empty track pages toward the click, like a GUI scrollbar
--
-- Geometry mirrors BufWindow.displayScrollBar in bufwindow.go: the bar is the
-- window's last column (X+Width-1), shown only when LinesNum > Height, with its
-- thumb top at Y + StartLine.Line/LinesNum*Height and height Height/LinesNum*
-- Height (min 1), in window rows. ScrollAdjust() re-clamps at EOF so a drag
-- can't overscroll, matching the nooverscroll plugin
local buffer = import("micro/buffer")

-- Gesture state, owned from a scrollbar-column press until its release. `captured`
-- swallows the whole gesture so a drag that strays off the column never starts a
-- text selection. `grab` is the offset (mouse row minus thumb top) when the press
-- landed on the thumb, or nil when it landed on the empty track (a track press
-- pages on click but never drags)
local captured = false
local grab = nil

-- Scrollbar geometry for the current view. Returns the window view, buffer line
-- count, bar column, thumb top row, and thumb height (in window rows); or nil if
-- the bar isn't shown because the buffer fits in the window
local function bar(bp)
  local v = bp:GetView()
  local lines = bp.Buf:LinesNum()
  if lines <= v.Height then
    return nil
  end
  local top = v.Y + math.floor(v.StartLine.Line / lines * v.Height)
  local size = math.max(1, math.floor(v.Height / lines * v.Height))
  return v, lines, v.X + v.Width - 1, top, size
end

-- Bound to MouseLeft before MousePress. Grab the thumb, page the track, or (off
-- the scrollbar) fall through to the normal MousePress
function press(bp, e)
  local v, lines, scrollx, top, size = bar(bp)
  local mx, my = e:Position()
  -- BufView().Height excludes the status line, bounding the bar's vertical extent
  local bufh = bp:BufView().Height
  -- Off the scrollbar (no bar, wrong column, or the status line row): normal click
  if not v or mx ~= scrollx or my < v.Y or my >= v.Y + bufh then
    captured = false
    return false
  end
  captured = true
  if my >= top and my < math.min(top + size, v.Y + bufh) then
    -- On the thumb: remember where it was grabbed and leave it put for now
    grab = my - top
  else
    -- On the empty track: page toward the click, like a GUI scrollbar
    grab = nil
    if my < top then
      bp:ScrollUp(bufh)
    else
      bp:ScrollDown(bufh)
    end
    bp:ScrollAdjust()
  end
  return true
end

-- Bound to MouseLeftDrag before MouseDrag. Drag the grabbed thumb; otherwise
-- swallow the gesture (track press) or fall through to normal selection
function drag(bp, e)
  if not captured then
    return false
  end
  if grab == nil then
    return true
  end
  local _, my = e:Position()
  local v, lines = bar(bp)
  if v then
    -- Scroll so the thumb top tracks the mouse, preserving the grab offset.
    -- Inverts displayScrollBar's barstart: line = (toprow - Y) / Height * LinesNum
    local line = math.max(0, math.floor((my - grab - v.Y) / v.Height * lines))
    v.StartLine = bp:SLocFromLoc(buffer.Loc(0, line))
    bp:SetView(v)
    -- Pin the last line to the bottom edge so the drag can't scroll past EOF
    bp:ScrollAdjust()
  end
  return true
end

-- Bound to MouseLeftRelease before MouseRelease. End the scrollbar gesture
function release(bp, e)
  if not captured then
    return false
  end
  captured = false
  grab = nil
  return true
end
