#!/usr/bin/env bash
# Quick-add to today's plan (itinerary) via a rofi prompt. Bound to Super+Y.
set -euo pipefail

text=$(printf '' | rofi -dmenu -p 'plan +' -lines 0) || exit 0
[ -n "${text:-}" ] && /home/curator/.bin/hud plan-add "$text"
