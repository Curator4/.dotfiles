#!/usr/bin/env bash
# Open the Themis curation inbox. Bound to the HUD footer's "to curate" line.
#
# The inbox is a local web page rather than an eww card on purpose: curating a
# claim means editing prose and, since the agent control landed, holding a short
# back-and-forth about it. eww has a single-line GTK entry and no scrollback, so
# that conversation does not fit. eww carries the nudge instead — see
# ~/.config/eww/scripts/themis-inbox-render — and this hands the actual work to
# the browser.
#
# The server is loopback-only and per-process CSRF-scoped, so an already-running
# instance is reused rather than restarted; a restart would invalidate the token
# in any tab the operator still has open.
set -uo pipefail

THEMIS=${THEMIS:-/home/curator/.local/bin/themis}
PORT=${THEMIS_UI_PORT:-8765}
URL="http://127.0.0.1:${PORT}/"

if ! curl -sf -o /dev/null --max-time 1 "$URL"; then
    setsid "$THEMIS" ui --bind 127.0.0.1 --port "$PORT" \
        >>"${XDG_STATE_HOME:-$HOME/.local/state}/themis-ui.log" 2>&1 &
    for _ in $(seq 1 30); do
        curl -sf -o /dev/null --max-time 1 "$URL" && break
        sleep 0.2
    done
fi

exec xdg-open "$URL" >/dev/null 2>&1
