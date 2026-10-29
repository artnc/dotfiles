# Load X resources
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# Mute system bell
xset -b

# Switch to Dvorak
setxkbmap us dvorak

# Touchpad tap settings
if command -v synclient > /dev/null; then
  synclient TapButton1=1  # single-finger -> left click
  synclient TapButton2=3  # double-finger -> right click
  synclient TapButton3=2  # triple-finger -> middle click
fi

# Enable XFCE notifications
# https://bbs.archlinux.org/viewtopic.php?id=202812
. /etc/X11/xinit/xinitrc.d/50-systemd-user.sh

# Load modifier key remappings
[[ -f ~/.Xmodmap ]] && xmodmap ~/.Xmodmap

# Set wallpaper
sh ~/.fehbg &

# Because nvidia driver makes fonts huge by default (?!)
[[ "$(cat /etc/hostname)" = "absol" ]] && xrandr --output DP-2 --dpi 96 --primary

# https://github.com/artnc/nyc-subway-dashboard
# https://github.com/google/xsecurelock/issues/114
export DASHBOARD_URL='http://localhost:10001/?s=139N:5&s=R26N,R26S:6&s=419N,419S:8&s=230S:11&s=A38N,A38S:10&s=M23N:10&s=E01N,PWTCJ:10&h=9:00-21:00'
export XSECURELOCK_AUTH_TIMEOUT=30
export XSECURELOCK_BLANK_TIMEOUT=-1
export XSECURELOCK_SAVER=/home/art/git/nyc-subway-dashboard/screensaver
export XSECURELOCK_SAVER_STOP_ON_BLANK=0

# Autostart programs
# https://wiki.archlinux.org/index.php/autostarting
# echo 'Starting ssh-agent...'
# eval `ssh-agent -s`
echo 'Starting numlockx...'
numlockx &
echo 'Starting xbindkeys...'
xbindkeys
echo 'Starting xfce4-power-manager...'
xfce4-power-manager &
echo 'Starting xss-lock...'
# https://github.com/google/xsecurelock?tab=readme-ov-file#automatic-locking
xset s 540 5
xss-lock -n /usr/lib/xsecurelock/dimmer -l -- xsecurelock &
echo 'Starting i3...'
exec i3 # Must be last command in this file!
