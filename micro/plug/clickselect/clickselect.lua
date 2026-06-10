-- Alt+click extends the selection from the previous click's anchor to the
-- Alt-clicked point, like Shift+click in GUI editors. micro has no built-in
-- action for this: MousePress always resets the selection and has no modifier
-- handling. Shift+click can't be used because Ghostty and tmux both reserve the
-- Shift modifier for terminal-native selection, so it never reaches micro.
-- Alt+click does reach micro since Ghostty's `macos-option-as-alt` reports
-- Option as a mouse modifier that tmux forwards to the app
local buffer = import("micro/buffer")

-- Bound to Alt-MouseLeft in bindings.json. micro passes the *tcell.EventMouse as
-- the second arg for mouse bindings (see runtime/help/plugins.md)
function extend(bp, e)
  local mx, my = e:Position()

  -- Ignore clicks below the buffer (e.g. the status line), matching MousePress
  local view = bp:BufView()
  if my >= view.Y + view.Height then
    return false
  end

  -- Extend the selection from the anchor that the prior plain click set via
  -- MousePress, so the highlight spans first-click to Alt-click
  local loc = bp:LocFromVisual(buffer.Loc(mx, my))
  bp.Cursor:SelectTo(loc)
  bp.Cursor:GotoLoc(loc)
  bp:Relocate()
  return true
end
