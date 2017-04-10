# Mute system bell
xset -b

# Switch to Dvorak
setxkbmap dvorak

# Touchpad tap settings
synclient TapButton1=1  # single-finger -> left click
synclient TapButton2=3  # double-finger -> right click
synclient TapButton3=2  # triple-finger -> middle click

# Enable XFCE notifications
# https://bbs.archlinux.org/viewtopic.php?id=202812
source /etc/X11/xinit/xinitrc.d/50-systemd-user.sh

# Load modifier key remappings
[[ -f ~/.Xmodmap ]] && xmodmap ~/.Xmodmap

# Set wallpaper
sh ~/.fehbg &

# Autostart programs
# https://wiki.archlinux.org/index.php/autostarting
easystroke &
xbindkeys
xss-lock -- ~/.config/i3/lock-screen.sh &

# Start i3 (must be last command in this file!)
#exec startxfce4
exec i3
