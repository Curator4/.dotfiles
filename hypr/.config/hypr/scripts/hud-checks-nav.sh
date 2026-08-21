#!/usr/bin/env bash
# Vim-nav for the checks card. Called from the Hyprland `checks` submap.
#   up|down|first|last   move the cursor
#   x|clear              checkmark, fade+slide, then ack
#   clear-at <n>         same, for a clicked line
set -uo pipefail

HUD=${HUD:-/home/curator/workspace/hud/hud}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/hud
LOCK=$STATE/checks-anim.lock
HOVER=$STATE/checks-hover

CURSOR=$STATE/checks-cursor

push_footer() {
    eww update board_checks="$("$HUD" checks render 2>/dev/null || true)" 2>/dev/null || true
}

refresh() {
    local rows
    rows=$("$HUD" checks --json 2>/dev/null || echo "[]")
    eww update checks_rows="$rows" 2>/dev/null || true
    push_footer
    if [ "$rows" = "[]" ]; then
        ~/.config/hypr/scripts/hud-checks.sh close
    fi
}

# j/k must not touch check.py. The live eww rows already have every index;
# stepping the highlight and writing the cursor file is the whole move.
move_cursor() {
    local op=$1
    local rows new next
    rows=$(eww get checks_rows 2>/dev/null || echo "[]")
    [ -n "$rows" ] && [ "$rows" != "[]" ] || exit 0
    new=$(printf '%s' "$rows" | jq -c --arg op "$op" '
        ([.[] | select(.item) | .i] | max // 0) as $max
        | if $max == 0 then .
          else
            ([.[] | select(.selected) | .i] | first // 1) as $cur
            | (if $op == "up" then
                 (if $cur <= 1 then 1 else $cur - 1 end)
               elif $op == "down" then
                 (if $cur >= $max then $max else $cur + 1 end)
               elif $op == "first" then 1
               else $max end) as $next
            | map(if .item then
                .selected = (.i == $next)
                | .klass = (if .i == $next
                    then "backlog-item-hit selected"
                    else "backlog-item-hit" end)
              else . end)
          end')
    next=$(printf '%s' "$new" | jq -r '[.[] | select(.selected) | .i] | first // 1')
    eww update checks_rows="$new" 2>/dev/null || true
    mkdir -p "$STATE"
    printf '%s\n' "$next" >"$CURSOR"
}

# Keep the dying row in the widget tree so the revealer can play, then
# ack after the slide finishes. A lock stops j/k/x from snapping the
# list back open mid-animation.
animate_clear() {
    local idx=$1
    local rows checked sliding
    mkdir -p "$(dirname "$LOCK")"
    if ! mkdir "$LOCK" 2>/dev/null; then
        exit 0
    fi
    rows=$("$HUD" checks --json 2>/dev/null || echo "[]")
    # 1) Check lands and sits. 2) Then fade+slide. Revealer only animates
    # on a property change, so reveal stays true until the hold is over.
    checked=$(printf '%s' "$rows" | jq -c --argjson i "$idx" '
        map(if .item and .i == $i then
              . + {revealed: true, mark: "✓",
                   klass: "backlog-item-hit selected checking", selected: true}
            else . end)')
    eww update checks_rows="$checked" 2>/dev/null || true
    (
        trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
        sleep 0.12
        sliding=$(printf '%s' "$checked" | jq -c --argjson i "$idx" '
            map(if .item and .i == $i then
                  . + {revealed: false, klass: "backlog-item-hit clearing"}
                else . end)')
        eww update checks_rows="$sliding" 2>/dev/null || true
        sleep 0.28
        "$HUD" checks-done "$idx" >/dev/null 2>&1 || true
        refresh
    ) &
}

case "${1:-}" in
    up|down|first|last)
        [ -d "$LOCK" ] && exit 0
        move_cursor "$1"
        ;;
    x|clear)
        idx=$("$HUD" checks-cursor get 2>/dev/null || echo 0)
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
        [ -n "$idx" ] || idx=$("$HUD" checks-cursor get 2>/dev/null || true)
        [ -n "$idx" ] && [ "$idx" -gt 0 ] 2>/dev/null || exit 0
        text=$("$HUD" checks-cursor yank "$idx") || exit 1
        printf '%s\n' "$text" | wl-copy
        notify-send -t 2500 checks "copied $text" 2>/dev/null || true
        ;;
    *)
        echo "usage: hud-checks-nav.sh <up|down|first|last|x|clear-at n|y>" >&2
        exit 2
        ;;
esac
