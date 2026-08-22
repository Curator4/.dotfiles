#!/usr/bin/env bash
# Scan-and-ack today's routine checks. Bound to Super+X; also the footer
# click and the `checks` fish command. Toggles the HUD-styled eww card and
# the vim submap (j/k move, x acks, Escape closes).
set -uo pipefail

HUD=${HUD:-/home/curator/workspace/hud/hud}
open=$(eww active-windows 2>/dev/null | grep -c '^checks:' || true)

close_card() {
    eww close checks 2>/dev/null || true
    hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
}

if [ "${1:-}" = "close" ] || [ "$open" -gt 0 ]; then
    close_card
    exit 0
fi

# One overlay at a time — the backlog card uses the same chrome and keys.
~/.config/hypr/scripts/hud-backlog.sh close

# Fresh session: drop hover state from the last one (see hud-backlog.sh —
# stale hover beats the cursor on y).
rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/hud/checks-hover"

rows=$("$HUD" checks --json 2>/dev/null || echo "[]")
if [ "$rows" = "[]" ]; then
    eww update board_checks="$("$HUD" checks render 2>/dev/null || true)" 2>/dev/null || true
    notify-send -t 2000 "checks" "nothing left today ✔"
    exit 0
fi

mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
[ -n "$mon" ] || mon=0
eww open --screen "$mon" checks
# Rows have to land after realize (a pre-open update is dropped). One
# update fills the widget tree at the empty-window size; a second pass
# is what makes gtk-layer-shell pick up the content height.
eww update checks_rows="$rows" >/dev/null
eww update checks_rows="$rows" >/dev/null
hyprctl dispatch 'hl.dsp.submap("checks")' >/dev/null
