#!/bin/bash
# Reskin the FOCUSED kitty window to a theme's terminal colors (per-window,
# same effect as typing the bare theme name in fish). Bound to Super+F1..F12.
# Usage: theme-term.sh <slug>
slug="$1"
TDIR="$HOME/.dotfiles/themes/$slug"
conf="$TDIR/kitty.conf"

if [ ! -f "$conf" ]; then
    notify-send "theme-term" "unknown theme: $slug" 2>/dev/null
    exit 1
fi

# PID of the focused window (= the kitty process pid for a kitty window)
pid=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty')
[ -n "$pid" ] || exit 0

# Reskin that kitty window's colors. No-op if the focused window isn't kitty.
kitty @ --to "unix:@mykitty-$pid" set-colors --all --configured "$conf" 2>/dev/null || exit 0

# Tint the window's hyprland border from the theme palette (if it has one)
border=$(jq -r '.palette.cursor // empty' "$TDIR/theme.json" 2>/dev/null)
[ -n "$border" ] && hyprctl dispatch setprop "pid:$pid" active_border_color "rgba(${border#\#}ee)" &>/dev/null
exit 0
