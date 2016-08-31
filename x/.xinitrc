# Mute system bell
xset -b

# Switch to Dvorak
setxkbmap dvorak

# Touchpad tap settings
synclient TapButton1=1  # single-finger -> left click
synclient TapButton2=3  # double-finger -> right click
synclient TapButton3=2  # triple-finger -> middle click

# Start XFCE (must be last command in this file!)
exec startxfce4
