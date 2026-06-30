#!/usr/bin/env bash
# Set macOS system settings

set -euo pipefail

defaults write NSGlobalDomain AppleICUDateFormatStrings -dict 1 "y-MM-dd"                                           # ISO 8601 short date format
defaults write NSGlobalDomain AppleICUForce24HourTime -bool true                                                    # 24-hour clock
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"                                                    # Dark mode
defaults write NSGlobalDomain AppleReduceDesktopTinting -bool true                                                  # Reduce wallpaper tinting in windows
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"                                                  # Always show scrollbars
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false                                            # Disable natural scrolling
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3                                                   # Max trackpad tracking speed
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true                                                # Tap to click
defaults write com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 0                              # Disable five-finger pinch (Launchpad)
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 0                         # Disable four-finger horizontal swipe
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture -int 0                              # Disable four-finger pinch (Launchpad)
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 0                        # Disable three-finger horizontal swipe (switch spaces)
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 0                  # Disable two-finger swipe from right edge (Notification Center)
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false                                         # No margins on tiled windows
defaults write com.apple.dock autohide -bool true                                                                   # Auto-hide
defaults write com.apple.dock expose-group-apps -bool true                                                          # Group windows by app in Mission Control
defaults write com.apple.dock launchanim -bool false                                                                # Don't animate app launches
defaults write com.apple.dock mru-spaces -bool false                                                                # Don't auto-rearrange Spaces based on recent use
defaults write com.apple.dock orientation -string "left"                                                            # Position on left
defaults write com.apple.dock show-recents -bool false                                                              # Don't show recent apps
defaults write com.apple.dock showDesktopGestureEnabled -bool false                                                 # Disable show-desktop trackpad gesture
defaults write com.apple.dock wvous-br-corner -int 1                                                                # Disable bottom-right hot corner
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true                               # Tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFiveFingerPinchGesture -int 0             # Disable five-finger pinch (Launchpad)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 0        # Disable four-finger horizontal swipe
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerPinchGesture -int 0             # Disable four-finger pinch (Launchpad)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 0       # Disable three-finger horizontal swipe (switch spaces)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 0 # Disable two-finger swipe from right edge (Notification Center)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"                                                 # Default to list view
defaults write com.apple.finder NewWindowTarget -string "PfAF"                                                      # New windows open Recents
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false                                                 # Don't show internal hard drives on desktop
defaults write com.apple.loginwindow TALLogoutSavesState -bool false                                                # Don't reopen windows on login
defaults write com.apple.menuextra.clock ShowSeconds -bool true                                                     # Show seconds in the clock
defaults write com.apple.screencapture location -string "/private/tmp"                                              # Save screenshots to /tmp instead of Desktop
defaults write com.apple.spaces spans-displays -bool true                                                           # All displays share one space (disable "Displays have separate Spaces")

# Disable hotkeys
hotkeys_plist="${HOME}/Library/Preferences/com.apple.symbolichotkeys.plist"
disable_hotkey() {
  /usr/libexec/PlistBuddy -c "Delete :AppleSymbolicHotKeys:${1}" "${hotkeys_plist}" 2> /dev/null || true
  /usr/libexec/PlistBuddy \
    -c "Add :AppleSymbolicHotKeys:${1} dict" \
    -c "Add :AppleSymbolicHotKeys:${1}:enabled bool false" \
    "${hotkeys_plist}"
}
for key in 15 16 17 18 19 20 21 22 23 24 25 26; do
  disable_hotkey "${key}" # Ctrl+1 through Ctrl+12 (switch to desktop N)
done
disable_hotkey 32  # Ctrl+Left Arrow (move left a space)
disable_hotkey 33  # Ctrl+Right Arrow (move right a space)
disable_hotkey 164 # Spotlight search
