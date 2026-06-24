#!/usr/bin/env bash
# Quick-capture, bound to Super+Y. Brain-dump a note in rofi; Haiku auto-routes
# it to the BACKLOG (a task/bug to do later) or today's ITINERARY (a time-bound
# thing). FOCUS is deliberate — it's the small set that gets injected into new
# sessions and drift-tracked — so it's only set via the "focus:" / "side:"
# prefix. "backlog:" / "today:" force those too.
set -uo pipefail

hud=/home/curator/.bin/hud
claude=/home/curator/.local/bin/claude
llmdir="$HOME/.local/state/hud/llm"
model=claude-haiku-4-5-20251001

trim() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

text=$(printf '' | rofi -dmenu -p 'capture +' -lines 0) || exit 0
text=$(printf '%s' "$text" | trim)
[ -z "$text" ] && exit 0

dest="" section="priorities"

# Explicit prefix override (skips the LLM).
case "$text" in
  focus:*)              dest=focus;                 text=${text#focus:} ;;
  side:*)               dest=focus; section=side;   text=${text#side:} ;;
  backlog:*)            dest=backlog;               text=${text#backlog:} ;;
  today:*|itinerary:*)  dest=itinerary;             text=${text#*:} ;;
esac
text=$(printf '%s' "$text" | trim)

# No prefix → Haiku routes between backlog and itinerary only (focus is never
# auto-assigned). Runs from a filtered dir with the recursion guard, so it never
# lands on the board or re-fires the HUD hooks.
if [ -z "$dest" ]; then
  mkdir -p "$llmdir" 2>/dev/null
  prompt="Route a captured note into ONE destination and tidy it into a short item.
Destinations:
- itinerary: a time-bound thing for TODAY (appointment, errand, \"watch the game 19:00\").
- backlog: anything else to do later — a task, bug, feature, or errand without a today deadline (e.g. \"fix the openclaw bug\", \"set up vaultwarden\").
When unsure, choose backlog.
Return ONLY minified JSON: {\"dest\":\"backlog|itinerary\",\"text\":\"<tidied item>\"}.
Note: $text"

  json=$(cd "$llmdir" && HUD_SUMMARIZING=1 "$claude" -p --model "$model" "$prompt" 2>/dev/null \
         | tr -d '\n' | grep -o '{.*}' | head -1)
  d=$(printf '%s' "$json" | jq -r '.dest // empty' 2>/dev/null)
  t=$(printf '%s' "$json" | jq -r '.text // empty' 2>/dev/null)
  [ -n "$d" ] && dest=$d
  [ -n "$t" ] && text=$t
fi

[ -z "$dest" ] && dest=backlog  # safe fallback: the pool, never focus

"$hud" capture --dest "$dest" --section "$section" "$text" >/dev/null 2>&1
notify-send -t 4000 "captured → ${dest}" "$text" 2>/dev/null || true
