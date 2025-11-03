-- Auto-reload Hammerspoon config
hs.alert("Config reloaded")
_configWatcher = hs.pathwatcher.new("/Users/art/.hammerspoon/init.lua", function()
  hs.reload()
end):start()

-- Disable disruptive macOS system keyboard shortcuts
hs.hotkey.bind({"cmd"}, 'H', function() end) -- Hide
hs.hotkey.bind({"cmd"}, 'M', function() end) -- Minimize to dock
hs.hotkey.bind({"cmd", "ctrl"}, 'F', function() end) -- Fullscreen

-- Auto-type email
local typeKeystrokes = function(email) return function() hs.eventtap.keyStrokes(email) end end
hs.hotkey.bind({"alt", "shift"}, "C", typeKeystrokes(string.reverse("moc.nuradiahc@tra")))
hs.hotkey.bind({"alt", "shift"}, "D", typeKeystrokes(string.reverse("moc.ogniloud@tra")))
hs.hotkey.bind({"alt", "shift"}, "E", typeKeystrokes(string.reverse("moc.liamg@nuradiahctra")))

-- Auto-type Claude Code keyword
hs.hotkey.bind({"alt", "shift"}, "U", typeKeystrokes(". ultrathink"))

-- Auto-refresh Slack upon focus and then periodically while focused
local slackRefreshInterval = 300 -- 5 minutes
local slackLastRefresh = 0
local slackFocusTimer = nil
local refreshSlack = function()
  hs.eventtap.keyStroke({"cmd", "shift"}, "r")
  slackLastRefresh = hs.timer.secondsSinceEpoch()
end
hs.application.watcher.new(function(appName, eventType, appObject)
  if appName ~= "Slack" then
    return
  end
  if eventType == hs.application.watcher.activated then
    -- Refresh on focus
    local now = hs.timer.secondsSinceEpoch()
    if (now - slackLastRefresh) >= slackRefreshInterval then
      hs.timer.doAfter(0.1, refreshSlack)
    end

    -- Start timer
    if slackFocusTimer then
      slackFocusTimer:stop()
    end
    slackFocusTimer = hs.timer.new(slackRefreshInterval, function()
      if hs.application.frontmostApplication():name() == "Slack" then
        refreshSlack()
      end
    end):start()
  elseif eventType == hs.application.watcher.deactivated then
    -- Stop timer
    if slackFocusTimer then
      slackFocusTimer:stop()
      slackFocusTimer = nil
    end
  end
end):start()
