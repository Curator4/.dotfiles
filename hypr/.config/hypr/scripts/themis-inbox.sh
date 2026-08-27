#!/usr/bin/env bash
# Toggle the Themis curation inbox. Bound to Super+Shift+T and the waybar
# count; the panel's own Escape reaches here through themis-panel-watchd.
#
# The window is a scratchpad: one chromeless chromium app window that lives
# forever, parked in special:themis (the themis-inbox-park rule sends every
# map there, so even a cold launch is invisible). Showing slides it up from
# below the panel monitor; hiding slides it down and re-parks it. The slide
# is a plain window move, animated by the windowsMove leaf — position-based,
# so it must happen where no other monitor's region lies underneath. DP-3 is
# the bottom-center monitor and the layout's bottom edge, which makes it the
# one monitor where the slide cannot bleed onto a neighbour (verified with
# frame captures 2026-08-27; parking below DP-1 rendered on DP-3).
#
# The server is loopback-only and its CSRF token is per process, so a running
# instance is reused rather than restarted — restarting would invalidate the
# token in a page the parked window still holds.
#
# Args: (none) toggle · close = hide only · warm = ensure server + parked
# window, never show (autostart) · kill = destroy window and browser process.
set -uo pipefail

THEMIS=${THEMIS:-/home/curator/.local/bin/themis}
BROWSER=${THEMIS_UI_BROWSER:-/usr/bin/chromium}
PORT=${THEMIS_UI_PORT:-8765}
URL="http://127.0.0.1:${PORT}/"
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/themis-ui
CLASS=themis-inbox
# 1200x706 at 1.333 scale renders the signed-off 900x530 layout a third
# larger — same proportions, bigger type. The panel rests docked to the
# monitor's bottom edge: it rises from the edge and sits on it.
PANEL_W=${THEMIS_PANEL_W:-1200}
PANEL_H=${THEMIS_PANEL_H:-706}
PANEL_SCALE=${THEMIS_PANEL_SCALE:-1.3333}
PANEL_BOTTOM_GAP=${THEMIS_PANEL_BOTTOM_GAP:-0}
PARK_MARGIN=60
PANEL_MONITOR=${THEMIS_PANEL_MONITOR:-DP-3}

mkdir -p "$STATE"

panel_state() { # -> "address ws-name x y", empty when no window
    hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys
try:
    clients = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    raise SystemExit(0)
for c in clients:
    if c.get("class") == "chrome-127.0.0.1__-Default":
        print(c["address"], c["workspace"]["name"], c["at"][0], c["at"][1])
        break
' 2>/dev/null
}

monitor_geometry() { # -> "x y w h active-ws global-bottom" for the panel monitor
    hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys, os
try:
    mons = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    raise SystemExit(0)
name = os.environ.get("PANEL_MONITOR", "DP-3")
pick = next((m for m in mons if m["name"] == name), None) \
    or next((m for m in mons if m.get("focused")), mons[0] if mons else None)
if pick is None:
    raise SystemExit(0)
bottom = max(m["y"] + m["height"] for m in mons)
print(pick["x"], pick["y"], pick["width"], pick["height"],
      pick["activeWorkspace"]["id"], bottom)
' 2>/dev/null
}

dispatch() {
    hyprctl eval "hl.dispatch($1)" >/dev/null 2>&1
}

ensure_server() {
    if ! curl -sf -o /dev/null --max-time 1 "$URL"; then
        setsid "$THEMIS" ui --bind 127.0.0.1 --port "$PORT" \
            >>"$STATE/server.log" 2>&1 &
        for _ in $(seq 1 30); do
            curl -sf -o /dev/null --max-time 1 "$URL" && break
            sleep 0.2
        done
    fi
}

ensure_window() { # sets ADDR/WS_NAME/AT_X; launches the parked window if needed
    read -r ADDR WS_NAME AT_X _ <<<"$(panel_state)"
    [[ -n ${ADDR:-} ]] && return 0
    ensure_server
    setsid "$BROWSER" \
        --app="$URL" \
        --ozone-platform=wayland \
        --class="$CLASS" \
        --user-data-dir="$STATE/profile" \
        --force-device-scale-factor="$PANEL_SCALE" \
        --no-first-run \
        --no-default-browser-check \
        --disable-extensions \
        >>"$STATE/browser.log" 2>&1 &
    for _ in $(seq 1 60); do
        read -r ADDR WS_NAME AT_X _ <<<"$(panel_state)"
        [[ -n ${ADDR:-} ]] && return 0
        sleep 0.25
    done
    return 1
}

show_panel() {
    read -r MON_X MON_Y MON_W MON_H MON_WS GLOBAL_BOTTOM <<<"$(PANEL_MONITOR=$PANEL_MONITOR monitor_geometry)"
    [[ -n ${MON_X:-} ]] || exit 0
    local x=$(( MON_X + (MON_W - PANEL_W) / 2 ))
    local y=$(( MON_Y + MON_H - PANEL_H - PANEL_BOTTOM_GAP ))
    local park_y=$(( GLOBAL_BOTTOM + PARK_MARGIN ))
    dispatch "hl.dsp.window.resize({ x = $PANEL_W, y = $PANEL_H, window = 'address:$ADDR' })"
    dispatch "hl.dsp.window.move({ x = $x, y = $park_y, window = 'address:$ADDR' })"
    dispatch "hl.dsp.window.move({ workspace = $MON_WS, silent = true, window = 'address:$ADDR' })"
    # The workspace move clamps an out-of-bounds float onto the monitor with
    # its own animation; let it resolve, then state the resting spot exactly.
    sleep 0.05
    dispatch "hl.dsp.window.move({ x = $x, y = $y, window = 'address:$ADDR' })"
    dispatch "hl.dsp.focus({ window = 'address:$ADDR' })"
}

hide_panel() {
    read -r _ _ _ _ _ GLOBAL_BOTTOM <<<"$(PANEL_MONITOR=$PANEL_MONITOR monitor_geometry)"
    local park_y=$(( ${GLOBAL_BOTTOM:-2880} + PARK_MARGIN ))
    dispatch "hl.dsp.window.move({ x = ${AT_X:-2270}, y = $park_y, window = 'address:$ADDR' })"
    sleep 0.55
    dispatch "hl.dsp.window.move({ workspace = 'special:themis', silent = true, window = 'address:$ADDR' })"
}

case "${1:-}" in
kill)
    read -r ADDR _ <<<"$(panel_state)"
    [[ -n ${ADDR:-} ]] && dispatch "hl.dsp.window.close({ window = 'address:$ADDR' })"
    pkill -f '^/usr/lib/chromium/chromium .*themis-ui/profile' 2>/dev/null
    exit 0
    ;;
warm)
    ensure_window || exit 1
    # A freshly mapped window is already parked by the themis-inbox-park rule;
    # one that was left visible by a crash gets put away.
    [[ ${WS_NAME:-} == special:* ]] || hide_panel
    exit 0
    ;;
close)
    read -r ADDR WS_NAME AT_X _ <<<"$(panel_state)"
    [[ -n ${ADDR:-} && ${WS_NAME:-} != special:* ]] && hide_panel
    exit 0
    ;;
*)
    ensure_window || exit 1
    if [[ ${WS_NAME:-} == special:* ]]; then
        show_panel
    else
        hide_panel
    fi
    ;;
esac
