# Start Sway when I log in on tty1 of a machine that has it. Check for it since
# a failed `exec` would end the login shell. Set the session vars that apps
# (e.g. Electron and Qt) check to pick Wayland, since pam_systemd sets
# `XDG_SESSION_TYPE=tty` and Sway sets neither. Pass `--unsupported-gpu` when
# the NVIDIA driver is loaded (e.g. on absol) to hide Sway's "Proprietary GPU
# drivers are not supported by sway. Do not report issues." error bar
if [[ -z ${WAYLAND_DISPLAY:-} && ${XDG_VTNR:-} == 1 && -n ${commands[sway]:-} ]]; then
  export XDG_CURRENT_DESKTOP=sway XDG_SESSION_TYPE=wayland
  exec sway $([[ -d /sys/module/nvidia ]] && echo --unsupported-gpu)
fi
