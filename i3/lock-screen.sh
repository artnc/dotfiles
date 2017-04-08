#!/bin/zsh

# Based on https://www.reddit.com/r/unixporn/comments/3358vu/i3lock_unixpornworthy_lock_screen/
scrot /tmp/screen.png
convert /tmp/screen.png -scale 5% -scale 2000% /tmp/screen.png
i3lock -i /tmp/screen.png
rm /tmp/screen.png
