-- Auto-dismiss transient InfoBar messages (e.g. "Saved", "Undid N actions") ~2s
-- after they appear, so they don't linger forever. Event-driven: each new
-- message arms a single one-shot timer instead of polling
local micro = import("micro")

local CLEAR_NS = 2000000000  -- 2s before a settled message is cleared
local gen = 0                -- bumped per armed message so a newer one supersedes
local armedMsg = nil         -- text of the message a timer is currently waiting on

-- Only plain confirmation/error text is dismissable; never touch an active
-- prompt (command bar, search, y/n, save-as)
local function dismissable(ib)
  return (ib.HasMessage or ib.HasError) and not ib.HasPrompt and not ib.HasYN
end

-- micro runs this after every event, i.e. right after an action sets a message.
-- Arm one dismissal per distinct message; unrelated keystrokes don't reset it
function onAnyEvent()
  local ib = micro.InfoBar()
  if not dismissable(ib) then
    armedMsg = nil
    return
  end
  if ib.Msg == armedMsg then
    return
  end
  armedMsg = ib.Msg
  gen = gen + 1
  local myGen = gen
  local target = ib.Msg
  micro.After(CLEAR_NS, function()
    -- skip if a newer message superseded this timer or the bar already moved on
    if myGen == gen then
      local now = micro.InfoBar()
      if dismissable(now) and now.Msg == target then
        now:Reset()
      end
      armedMsg = nil
    end
  end)
end
