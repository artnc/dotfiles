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
local typeEmail = function(email) return function() hs.eventtap.keyStrokes(email) end end
hs.hotkey.bind({"alt", "shift"}, "C", typeEmail(string.reverse("moc.nuradiahc@tra")))
hs.hotkey.bind({"alt", "shift"}, "D", typeEmail(string.reverse("moc.ogniloud@tra")))
hs.hotkey.bind({"alt", "shift"}, "E", typeEmail(string.reverse("moc.liamg@nuradiahctra")))
