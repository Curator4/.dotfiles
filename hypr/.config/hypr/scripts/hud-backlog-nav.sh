#!/usr/bin/env bash
# Vim-nav for the backlog card. Called from the Hyprland `backlog` submap.
#   up|down|first|last   move the cursor
#   x|clear              checkmark, fade+slide, then remove
#   clear-at <n>         same, for a clicked line
set -uo pipefail

HUD=${HUD:-/home/curator/workspace/hud/hud}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/hud
LOCK=$STATE/backlog-anim.lock
HOVER=$STATE/backlog-hover

refresh() {
    local rows
    rows=$("$HUD" backlog --json 2>/dev/null || echo "[]")
    eww update backlog_rows="$rows" 2>/dev/null || true
    if [ "$rows" = "[]" ]; then
        ~/.config/hypr/scripts/hud-backlog.sh close
    fi
}

# Keep the dying row in the widget tree so the revealer can play, then
# delete the file after the slide finishes. A lock stops j/k/x from
# snapping the list back open mid-animation.
animate_clear() {
    local idx=$1
    local rows patched
    mkdir -p "$(dirname "$LOCK")"
    if ! mkdir "$LOCK" 2>/dev/null; then
        exit 0
    fi
    rows=$("$HUD" backlog --json 2>/dev/null || echo "[]")
    # 1) Check lands and sits. 2) Then fade+slide. Revealer only animates
    # on a property change, so reveal stays true until the hold is over.
    checked=$(printf '%s' "$rows" | jq -c --argjson i "$idx" '
        map(if .item and .i == $i then
              . + {revealed: true, mark: "✓",
                   klass: "backlog-item-hit selected checking", selected: true}
            else . end)')
    eww update backlog_rows="$checked" 2>/dev/null || true
    (
        trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
        sleep 0.12
        sliding=$(printf '%s' "$checked" | jq -c --argjson i "$idx" '
            map(if .item and .i == $i then
                  . + {revealed: false, klass: "backlog-item-hit clearing"}
                else . end)')
        eww update backlog_rows="$sliding" 2>/dev/null || true
        sleep 0.28
        "$HUD" backlog-done "$idx" >/dev/null 2>&1 || true
        refresh
    ) &
}

case "${1:-}" in
    up|down|first|last)
        [ -d "$LOCK" ] && exit 0
        "$HUD" backlog-cursor "$1" >/dev/null
        refresh
        ;;
    x|clear)
        idx=$("$HUD" backlog-cursor get 2>/dev/null || echo 0)
        [ "$idx" -gt 0 ] 2>/dev/null || exit 0
        animate_clear "$idx"
        ;;
    clear-at)
        [ -n "${2:-}" ] || exit 1
        animate_clear "$2"
        ;;
    hover)
        [ -n "${2:-}" ] || exit 1
        mkdir -p "$STATE"
        printf '%s\n' "$2" >"$HOVER"
        ;;
    unhover)
        if [ -n "${2:-}" ] && [ -f "$HOVER" ] && [ "$(cat "$HOVER")" = "$2" ]; then
            rm -f "$HOVER"
        fi
        ;;
    y|yank)
        idx=""
        [ -f "$HOVER" ] && idx=$(tr -cd '0-9' <"$HOVER")
        [ -n "$idx" ] || idx=$("$HUD" backlog-cursor get 2>/dev/null || true)
        [ -n "$idx" ] && [ "$idx" -gt 0 ] 2>/dev/null || exit 0
        text=$("$HUD" backlog-cursor yank "$idx") || exit 1
        printf '%s\n' "$text" | wl-copy
        notify-send -t 2500 backlog "copied item $idx" 2>/dev/null || true
        ;;
    *)
        echo "usage: hud-backlog-nav.sh <up|down|first|last|x|clear-at n|y>" >&2
        exit 2
        ;;
esac
