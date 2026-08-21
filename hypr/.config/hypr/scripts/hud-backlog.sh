#!/usr/bin/env bash
# Scan-and-check-off the household backlog. Bound to Super+Shift+B; also the
# `backlog` fish command. Toggles the HUD-styled eww card and the vim submap
# (j/k move, x clears, Escape closes).
set -uo pipefail

HUD=${HUD:-/home/curator/workspace/hud/hud}
open=$(eww active-windows 2>/dev/null | grep -c '^backlog:' || true)

close_card() {
    eww close backlog 2>/dev/null || true
    hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
}

if [ "${1:-}" = "close" ] || [ "$open" -gt 0 ]; then
    close_card
    exit 0
fi

# One overlay at a time — the checks card uses the same chrome and keys.
~/.config/hypr/scripts/hud-checks.sh close

mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
[ -n "$mon" ] || mon=0
rows=$("$HUD" backlog --json 2>/dev/null || echo "[]")
eww open --screen "$mon" backlog
# Rows have to land after realize (a pre-open update is dropped). One
# update fills the widget tree at the empty-window size; a second pass
# is what makes gtk-layer-shell pick up the content height.
eww update backlog_rows="$rows" >/dev/null
eww update backlog_rows="$rows" >/dev/null
hyprctl dispatch 'hl.dsp.submap("backlog")' >/dev/null
