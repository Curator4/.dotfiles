#!/usr/bin/env bash
# Quick-capture, bound to Super+Y. Brain-dump a note in rofi; Haiku routes it to
# the BACKLOG (a task/bug to do later) or today's ITINERARY (a time-bound thing)
# and files it. Focus is managed conversationally via the `hud` MCP tools — not
# here — so there are no prefixes: just dump and it files.
set -uo pipefail

hud=/home/curator/.bin/hud
claude=/home/curator/.local/bin/claude
llmdir="$HOME/.local/state/hud/llm"
model=claude-haiku-4-5-20251001

text=$(printf '' | rofi -dmenu -p 'capture +' -lines 0) || exit 0
text=$(printf '%s' "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
[ -z "$text" ] && exit 0

# Haiku routes between backlog and itinerary. Runs from a filtered dir with the
# recursion guard, so it never lands on the board or re-fires the HUD hooks.
mkdir -p "$llmdir" 2>/dev/null
prompt="Route a captured note into ONE destination and tidy it into a short item.
Destinations:
- itinerary: a time-bound thing for TODAY (appointment, errand, \"watch the game 19:00\").
- backlog: anything else to do later — a task, bug, feature, or errand without a today deadline.
When unsure, choose backlog.
Return ONLY minified JSON: {\"dest\":\"backlog|itinerary\",\"text\":\"<tidied item>\"}.
Note: $text"

json=$(cd "$llmdir" && HUD_SUMMARIZING=1 "$claude" -p --model "$model" "$prompt" 2>/dev/null \
       | tr -d '\n' | grep -o '{.*}' | head -1)
dest=$(printf '%s' "$json" | jq -r '.dest // empty' 2>/dev/null)
tidied=$(printf '%s' "$json" | jq -r '.text // empty' 2>/dev/null)
[ -n "$tidied" ] && text=$tidied
case "$dest" in backlog | itinerary) ;; *) dest=backlog ;; esac # never focus

"$hud" capture --dest "$dest" "$text" >/dev/null 2>&1
notify-send -t 4000 "captured → ${dest}" "$text" 2>/dev/null || true
