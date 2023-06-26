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

-- Snap windows
hs.window.animationDuration = 0
local snap = function(fn) return function()
  local win = hs.window.focusedWindow()
  local f = win:screen():frame()
  win:setFrame(fn(f))
end end
hs.hotkey.bind({"alt"}, "U", snap(function(f) return f end))
hs.hotkey.bind({"cmd", "alt"}, "Left",
  snap(function(f) return hs.geometry.rect(f.x, f.y, f.w / 2, f.h) end))
hs.hotkey.bind({"cmd", "alt"}, "Right",
  snap(function(f) return hs.geometry.rect(f.x + (f.w / 2), f.y, f.w / 2, f.h) end))
hs.hotkey.bind({"cmd", "alt"}, "Up",
  snap(function(f) return hs.geometry.rect(f.x, f.y, f.w, f.h / 2) end))
hs.hotkey.bind({"cmd", "alt"}, "Down",
  snap(function(f) return hs.geometry.rect(f.x, f.y + (f.h / 2), f.w, f.h / 2) end))

-- Implement i3-like spaces. We do this all in a single macOS space (a.k.a
-- desktop) because macOS desktops:
--
--   - Have an unavoidable transition animation (either wipe or cross-fade)
--   - Are much slower to programmatically navigate between (100ms vs ~0ms)
--   - Have poor API exposure and are thus hackily implemented in Hammerspoon,
--     causing bugs like https://github.com/Hammerspoon/hammerspoon/issues/3276
--
-- This requires disabling the macOS option "Displays have separate Spaces",
-- which has the side benefit of automatically moving all windows to the laptop
-- screen (as opposed to just nuking them) upon disconnect of external monitors
-- but also the annoyance of removing menu bars from external monitors.
--
-- We use Hammerspoon instead of Yabai because the latter requires disabling
-- System Integrity Protection.
local registeredApps = {
  -- The array of elements at index N correspond to synthetic space N
  {space=1, fn=(function(app, win) return app == "Firefox" and not win:find(" Private Browsing$") end)},
  {space=2, win=" Private Browsing$"},
  {space=3, app="Sublime Text", layout=hs.geometry.rect(0, 0, 0.55, 1)},
  {space=3, app="Alacritty", layout=hs.geometry.rect(0.55, 0, 0.45, 1)},
  {space=4, app="Slack"},
  {space=5, app="Xcode", layout=hs.geometry.rect(0, 0, 0.66, 1)},
  {space=5, app="Simulator", layout=hs.geometry.rect(0.66, 0, 0.34, 1)},
  {space=6, app="KeePassXC", layout=hs.layout.left50},
  {space=6, win="^Zoom$", layout=hs.layout.right50},
  {space=7, app="Finder"},
  {space=8, app="GIMP"},
  {space=9, win="Zoom Meeting"},
}
local unregisteredWindows = {}
local cacheWindows = function()
  unregisteredWindows = {}
  for _, app in pairs(registeredApps) do app.window = nil end
  for _, window in pairs(hs.window.allWindows()) do
    local isWindowRegistered = false
    for _, app in pairs(registeredApps) do
      if not app.window then
        local isMatch = false
        if app.win then
          isMatch = window:title():find(app.win)
        elseif app.fn then
          isMatch = app.fn(window:application():title(), window:title())
        else
          isMatch = app.app == window:application():title()
        end
        if isMatch then
          app.window = window
          isWindowRegistered = true
          break
        end
      end
    end
    if not isWindowRegistered then table.insert(unregisteredWindows, window) end
  end
end
cacheWindows()
hs.window.filter.new(true)
  :subscribe(hs.window.filter.windowCreated, cacheWindows)
  :subscribe(hs.window.filter.windowDestroyed, cacheWindows)
local screens={
  laptop={uuid="37D8832A-2D66-02CA-B9F7-8F30A301B230", name="Built-in Retina Display"},
  horizontal={uuid="0F8F8E39-57DB-49A9-B0C7-B073C0CEB6F1", name="DELL U2723QE"},
  vertical={uuid="6610D292-12B9-41C4-B1A1-BBACC986AA8B", name="DELL P2715Q"},
}
local switchToSpace = function(spaceNum)
  local start = hs.timer.absoluteTime()

  -- Determine target screen
  local spaces = hs.spaces.allSpaces() -- 0ms
  local targetScreen = (spaceNum == 4 and spaces[screens.vertical.uuid])
    and screens.vertical
    or ((spaceNum == 3 or spaceNum == 5) and spaces[screens.horizontal.uuid])
    and screens.horizontal or screens.laptop

  -- Define window raising helper
  local shouldMoveCursor = hs.window.focusedWindow():screen():getUUID()
    ~= targetScreen.uuid
  local raiseWindow = function(window, layout)
    hs.spaces.moveWindowToSpace(window, spaces[targetScreen.uuid][1])
    if layout then
      hs.layout.apply({{nil, window, targetScreen.name, layout, nil, nil}})
    end
    window:focus()
    if shouldMoveCursor then
      local screen = hs.screen.find(targetScreen.uuid)
      local f = screen:frame()
      hs.mouse.setRelativePosition(hs.geometry.point(f.w / 2, f.h / 2), screen)
      shouldMoveCursor = false
    end
  end

  -- Raise window(s)
  for i, app in pairs(registeredApps) do
    local window = app.window
    if window then
      if spaceNum then
        if app.space == spaceNum then
          raiseWindow(window, app.layout or hs.layout.maximized)
        end
      else
        window:application():hide()
      end
    end
  end
  if not spaceNum then
    for _, window in pairs(unregisteredWindows) do
      raiseWindow(window)
    end
  end

  -- hs.alert(math.floor((hs.timer.absoluteTime() - start) / 1000000) .. "ms")
  cacheWindows()
end
for i=1, 9 do
  hs.hotkey.bind({"alt"}, tostring(i), function() switchToSpace(i) end)
end
hs.hotkey.bind({"alt"}, "0", function() switchToSpace() end)

-- Reposition windows after [dis/]connecting external monitors
_screenWatcher = hs.screen.watcher.new(function()
  switchToSpace(5)
  switchToSpace(3)
  switchToSpace(4)
  switchToSpace(1)
end):start()
