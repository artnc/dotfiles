# Mute system bell
xset -b

# Switch to Dvorak
setxkbmap us dvorak

# Touchpad tap settings
command -v synclient > /dev/null && {
  synclient TapButton1=1  # single-finger -> left click
  synclient TapButton2=3  # double-finger -> right click
  synclient TapButton3=2  # triple-finger -> middle click
}

# Enable XFCE notifications
# https://bbs.archlinux.org/viewtopic.php?id=202812
. /etc/X11/xinit/xinitrc.d/50-systemd-user.sh

# Load modifier key remappings
[[ -f ~/.Xmodmap ]] && xmodmap ~/.Xmodmap

# Set wallpaper
sh ~/.fehbg &

# Because nvidia driver makes fonts huge by default (?!)
[[ "$(hostname)" = "absol" ]] && xrandr --output DP-2 --dpi 96 --primary

# Autostart programs
# https://wiki.archlinux.org/index.php/autostarting
echo 'Starting easystroke...'
easystroke &
echo 'Starting ssh-agent...'
eval `ssh-agent -s`
# echo 'Starting mullvad-vpn...'
# mullvad-vpn &
echo 'Starting numlockx...'
numlockx &
echo 'Starting syncthing-gtk...'
syncthing-gtk &
echo 'Starting xbindkeys...'
xbindkeys
echo 'Starting xfce4-power-manager...'
xfce4-power-manager &
echo 'Starting xss-lock...'
xss-lock -- ~/.config/i3/lock-screen.sh &
echo 'Starting i3...'
exec i3 # Must be last command in this file!
