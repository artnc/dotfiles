VERSION = "0.1.0"

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
