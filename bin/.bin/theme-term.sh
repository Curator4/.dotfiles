#!/bin/bash
# Reskin the FOCUSED kitty window to a theme's terminal colors (per-window,
# same effect as typing the bare theme name in fish). Bound to Super+F1..F12
# and Super+F13.. (keybinds.lua).
# Usage:
#   theme-term.sh <slug>
#   theme-term.sh --record <pid> <slug>
#   theme-term.sh --forget <pid>
#
# --record/--forget update ~/.local/state/agent-cue/term-theme/<pid> so
# standalone agent-cue toasts can match this window without inheriting env.

STATE_DIR="$HOME/.local/state/agent-cue/term-theme"

record_theme() {
    local pid="$1" slug="$2" f base
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    if [ -n "$slug" ] && [[ ! "$slug" =~ ^[a-z0-9-]+$ ]]; then
        return 1
    fi
    mkdir -p "$STATE_DIR"
    for f in "$STATE_DIR"/*; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        if [[ ! "$base" =~ ^[0-9]+$ ]] || [ ! -d "/proc/$base" ]; then
            rm -f "$f"
        fi
    done
    if [ -n "$slug" ]; then
        printf '%s\n' "$slug" > "$STATE_DIR/$pid"
    else
        rm -f "$STATE_DIR/$pid"
    fi
}

if [ "$1" = "--record" ]; then
    record_theme "$2" "$3"
    exit $?
fi
if [ "$1" = "--forget" ]; then
    record_theme "$2" ""
    exit $?
fi

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
record_theme "$pid" "$slug"

# Tint the window's hyprland border from the theme palette (if it has one).
# Themes may set `border` explicitly; otherwise the cursor colour stands in.
# The config is Lua (hyprland.lua), so `hyprctl dispatch` evaluates its argument
# as Lua — the old `setprop "pid:N" prop value` form is a parse error.
set_prop() {
    hyprctl dispatch \
        "hl.dsp.window.set_prop({ window = \"pid:$pid\", prop = \"$1\", value = \"$2\" })" \
        &>/dev/null
}

border=$(jq -r '.palette.border // .palette.cursor // empty' "$TDIR/theme.json" 2>/dev/null)
[ -n "$border" ] && set_prop active_border_color "rgba(${border#\#}ee)"

# grok-night additionally blends the *inactive* border into the terminal bg, so
# an unfocused grok window shows no frame around the TUI's dark canvas. The
# background itself already comes from the theme conf loaded above.
if [ "$slug" = "grok-night" ]; then
    set_prop inactive_border_color "rgba(131414ee)"
fi

exit 0
