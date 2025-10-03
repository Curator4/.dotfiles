# Auto-start Hyprland via UWSM on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
  exec uwsm start hyprland-uwsm.desktop
fi
