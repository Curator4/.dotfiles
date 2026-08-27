#!/usr/bin/env bash
# Toggle the Themis curation inbox. Bound to Super+T and the waybar count;
# the panel's own Escape reaches here through themis-panel-watchd.
#
# The window lives permanently in special:themis (the themis-inbox-park rule
# sends every map there, so even a cold launch is invisible) and never
# changes workspace. Showing and hiding toggle the special-workspace overlay
# on the panel monitor — the compositor's own slide-from-the-top animation
# (specialWorkspace leaf, styled in theme-render.sh), monitor-clipped, so
# nothing bleeds onto the monitors above or beside it. toggle_special opens
# on the focused monitor, so the show focuses the panel monitor first, in
# the same eval; a close works from anywhere.
#
# The server is loopback-only and its CSRF token is per process, so a running
# instance is reused rather than restarted — restarting would invalidate the
# token in a page the hidden window still holds.
#
# Args: (none) toggle · close = hide only · warm = ensure server + hidden
# window, never show (autostart) · kill = destroy window and browser process.
set -uo pipefail

THEMIS=${THEMIS:-/home/curator/.local/bin/themis}
BROWSER=${THEMIS_UI_BROWSER:-/usr/bin/chromium}
PORT=${THEMIS_UI_PORT:-8765}
URL="http://127.0.0.1:${PORT}/"
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/themis-ui
CLASS=themis-inbox
# 1200-wide at 1.333 scale renders the signed-off 900-wide layout a third
# larger — same proportions, bigger type. The window spans from the top
# margin to a symmetric bottom margin; the page paints only the 530-CSS-px
# card until the counsel drawer expands into the rest (the surface below is
# transparent). 1344 = DP-3 height 1440 - 2x48 margins.
PANEL_W=${THEMIS_PANEL_W:-1200}
PANEL_H=${THEMIS_PANEL_H:-1344}
PANEL_SCALE=${THEMIS_PANEL_SCALE:-1.3333}
PANEL_MARGIN_TOP=${THEMIS_PANEL_MARGIN_TOP:-48}
PANEL_MONITOR=${THEMIS_PANEL_MONITOR:-DP-3}

mkdir -p "$STATE"

panel_address() {
    hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys
try:
    clients = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    raise SystemExit(0)
for c in clients:
    if c.get("class") == "chrome-127.0.0.1__-Default":
        print(c["address"])
        break
' 2>/dev/null
}

overlay_open() {
    hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
try:
    mons = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    raise SystemExit(0)
for m in mons:
    if m.get("specialWorkspace", {}).get("name") == "special:themis":
        print("open")
        break
' 2>/dev/null
}

monitor_geometry() { # -> "x y w h active-ws" for the panel monitor
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
print(pick["x"], pick["y"], pick["width"], pick["height"], pick["activeWorkspace"]["id"])
' 2>/dev/null
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

ensure_window() { # sets ADDR; launches the hidden window if needed
    ADDR=$(panel_address)
    [[ -n ${ADDR:-} ]] && return 0
    ensure_server
    setsid "$BROWSER" \
        --app="$URL" \
        --ozone-platform=wayland \
        --class="$CLASS" \
        --user-data-dir="$STATE/profile" \
        --force-device-scale-factor="$PANEL_SCALE" \
        --default-background-color=00000000 \
        --no-first-run \
        --no-default-browser-check \
        --disable-extensions \
        >>"$STATE/browser.log" 2>&1 &
    for _ in $(seq 1 60); do
        ADDR=$(panel_address)
        [[ -n ${ADDR:-} ]] && return 0
        sleep 0.25
    done
    return 1
}

show_panel() {
    read -r MON_X MON_Y MON_W _ MON_WS <<<"$(PANEL_MONITOR=$PANEL_MONITOR monitor_geometry)"
    [[ -n ${MON_X:-} ]] || exit 0
    local x=$(( MON_X + (MON_W - PANEL_W) / 2 ))
    local y=$(( MON_Y + PANEL_MARGIN_TOP ))
    # One eval, one config tick: aim the toggle at the panel monitor by
    # focusing its active workspace (focus({monitor=...}) is silently
    # ignored, learned the hard way), state the position while still hidden,
    # open the overlay, take the keyboard.
    hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = $MON_WS })); hl.dispatch(hl.dsp.window.move({ x = $x, y = $y, window = 'address:$ADDR' })); hl.dispatch(hl.dsp.workspace.toggle_special('themis')); hl.dispatch(hl.dsp.focus({ window = 'address:$ADDR' }))" >/dev/null 2>&1
}

hide_panel() {
    [[ $(overlay_open) == open ]] && \
        hyprctl eval "hl.dispatch(hl.dsp.workspace.toggle_special('themis'))" >/dev/null 2>&1
}

case "${1:-}" in
kill)
    hide_panel
    pkill -f '^/usr/lib/chromium/chromium .*themis-ui/profile' 2>/dev/null
    exit 0
    ;;
warm)
    ensure_window || exit 1
    exit 0
    ;;
close)
    hide_panel
    exit 0
    ;;
*)
    ensure_window || exit 1
    if [[ $(overlay_open) == open ]]; then
        hide_panel
    else
        show_panel
    fi
    ;;
esac
