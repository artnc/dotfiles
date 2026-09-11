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

-- Mute audio except when on home Wi-Fi
-- https://github.com/Hammerspoon/hammerspoon/issues/3537
hs.location.start()
local muteUnlessHome = function()
  hs.audiodevice.defaultOutputDevice():setMuted(hs.wifi.currentNetwork() ~= "Art")
end
muteUnlessHome()
_wifiWatcher = hs.wifi.watcher.new(muteUnlessHome):start()
