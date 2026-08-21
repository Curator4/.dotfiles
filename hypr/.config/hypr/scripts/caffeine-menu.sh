#!/usr/bin/env bash
# rofi picker for caffeine doses (bound to Super+Shift+X).
# Presets only — pick, Enter, done. status / undo are actions, not drinks.
set -euo pipefail

HUD=/home/curator/workspace/hud/hud

# The HUD footer polls every 2s, which is fine most of the time but laggy for
# the one moment the operator is looking at it — right after a dose. Push the
# new line straight into eww so the count updates as the menu closes.
push_hud() {
    eww update board_caffeine="$("$HUD" caffeine render)" 2>/dev/null || :
}

list=$("$HUD" caffeine menu)
sel=$(rofi -dmenu -i -p 'caffeine' <<<"$list") || exit 0
[ -z "$sel" ] && exit 0

# First ASCII word is the command — leading emoji on drink rows is skipped.
cmd=$(awk '{
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^[A-Za-z]/) { print $i; exit }
    }
}' <<<"$sel")
case "$cmd" in
    coffee|monster)
        "$HUD" caffeine "$cmd" --source rofi
        push_hud
        ;;
    status)
        out=$("$HUD" caffeine status)
        notify-send -t 3000 -a caffeine "☕ caffeine" "$out"
        ;;
    undo)
        "$HUD" caffeine undo
        push_hud
        ;;
    *)
        notify-send -t 2000 -a caffeine "☕ caffeine" "unknown: $sel"
        exit 1
        ;;
esac
