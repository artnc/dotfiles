-- Make Ctrl-W close the current tab, or reset to a blank buffer when only one tab is open (avoids quitting micro)
local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")

local function smartquit(bp)
  if #micro.Tabs().List > 1 then
    bp:Quit()
    return
  end
  if bp.Buf:Modified() then
    micro.InfoBar():Error("Save changes first (Ctrl-S)")
    return
  end
  bp:OpenBuffer(buffer.NewBuffer("", ""))
end

function init()
  config.MakeCommand("smartquit", smartquit, config.NoComplete)
end
