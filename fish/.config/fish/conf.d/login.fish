# Auto-start Hyprland via UWSM on TTY1
if not set -q WAYLAND_DISPLAY; and test "$XDG_VTNR" = 1
    exec uwsm start hyprland-uwsm.desktop
end
