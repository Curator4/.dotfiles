#!/usr/bin/env bash
# Open the Themis curation inbox. Bound to Super+Shift+T and to the HUD
# footer's "to curate" line.
#
# The inbox is a local web page rather than an eww card on purpose: curating a
# claim means editing prose and, since the agent control landed, holding a short
# back-and-forth about it. eww has a single-line GTK entry and no scrollback, so
# that conversation does not fit. eww carries the nudge instead — see
# ~/.config/eww/scripts/themis-inbox-render.
#
# It opens chromeless, in its own Hyprland window, under a throwaway profile:
# no tabs, no address bar, no extensions, and nothing shared with the browsing
# session. The window class is fixed so rules.conf can float and size it.
#
# The server is loopback-only and its CSRF token is per process, so a running
# instance is reused rather than restarted — restarting would invalidate the
# token in a window the operator still has open.
set -uo pipefail

THEMIS=${THEMIS:-/home/curator/.local/bin/themis}
BROWSER=${THEMIS_UI_BROWSER:-/usr/bin/chromium}
PORT=${THEMIS_UI_PORT:-8765}
URL="http://127.0.0.1:${PORT}/"
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/themis-ui
CLASS=themis-inbox

mkdir -p "$STATE"

if ! curl -sf -o /dev/null --max-time 1 "$URL"; then
    setsid "$THEMIS" ui --bind 127.0.0.1 --port "$PORT" \
        >>"$STATE/server.log" 2>&1 &
    for _ in $(seq 1 30); do
        curl -sf -o /dev/null --max-time 1 "$URL" && break
        sleep 0.2
    done
fi

# Already showing? Focus it instead of stacking another window. Chromium ignores
# --class on Wayland and names the window after the URL, so match the title
# Themis itself sets.
if hyprctl clients -j 2>/dev/null | grep -q '"title": "[^"]*Themis'; then
    exec hyprctl dispatch \
        "hl.dsp.window.focus({ window = 'title:.*Themis.*' })" >/dev/null 2>&1
fi

if [[ ! -x $BROWSER ]]; then
    exec xdg-open "$URL" >/dev/null 2>&1
fi

setsid "$BROWSER" \
    --app="$URL" \
    --class="$CLASS" \
    --user-data-dir="$STATE/profile" \
    --no-first-run \
    --no-default-browser-check \
    --disable-extensions \
    >>"$STATE/browser.log" 2>&1 &

# Float, size and centre it here rather than through windowrule. rules.conf
# tags anything matching "chrom(e|ium)" — this window included — and forces
# tile = on, and a float rule placed after it does not win. Dispatching once
# the window exists is the version that actually holds.
for _ in $(seq 1 40); do
    address=$(hyprctl clients -j 2>/dev/null |
        python3 -c '
import json, sys
try:
    clients = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    raise SystemExit(0)
for client in clients:
    if "Themis" in (client.get("title") or ""):
        print(client["address"])
        break
' 2>/dev/null)
    [[ -n $address ]] && break
    sleep 0.25
done

[[ -n ${address:-} ]] || exit 0

# Hyprland 0.56 dispatchers are Lua and take a table, not a string. Passing a
# bare "address:0x..." string parses fine and reports ok, but silently acts on
# the active window instead of the one named — so the window key matters.
hyprctl dispatch "hl.dsp.window.float({ window = 'address:$address' })" >/dev/null 2>&1
hyprctl dispatch "hl.dsp.window.resize({ x = 900, y = 1000, window = 'address:$address' })" >/dev/null 2>&1
hyprctl dispatch "hl.dsp.window.center({ window = 'address:$address' })" >/dev/null 2>&1
