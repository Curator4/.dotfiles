#!/usr/bin/env bash
# Quick-capture, bound to Super+Y. Brain-dump a note in rofi; Haiku routes it to
# FOCUS (your own priorities), the BACKLOG (a task/bug to do), or today's
# ITINERARY, and files it. Prefix with "focus:", "side:", "backlog:" or "today:"
# to force the destination and skip the LLM.
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

# No override → Haiku classifies + tidies. Runs from a filtered dir with the
# recursion guard, so it never lands on the board or re-fires the HUD hooks.
if [ -z "$dest" ]; then
  mkdir -p "$llmdir" 2>/dev/null
  prompt="You route a captured note in a personal system into ONE destination and tidy it into a short item.
Destinations:
- focus: the operator's OWN work priorities/intentions — to do, decide, follow up, or plan (e.g. \"close out AR 222\", \"make a work roadmap\"). Pick section \"priorities\" (work) or \"side\" (side projects: dynasty, calliope, council, household tooling, this session tracker).
- backlog: a concrete task/bug/feature to be done later, often delegatable (e.g. \"fix the openclaw bug\", \"set up vaultwarden\").
- itinerary: a time-bound thing for TODAY (appointment, errand, \"watch the game 19:00\").
Return ONLY minified JSON: {\"dest\":\"focus|backlog|itinerary\",\"section\":\"priorities|side\",\"text\":\"<tidied item>\"}.
Note: $text"

  json=$(cd "$llmdir" && HUD_SUMMARIZING=1 "$claude" -p --model "$model" "$prompt" 2>/dev/null \
         | tr -d '\n' | grep -o '{.*}' | head -1)
  d=$(printf '%s' "$json" | jq -r '.dest // empty' 2>/dev/null)
  s=$(printf '%s' "$json" | jq -r '.section // empty' 2>/dev/null)
  t=$(printf '%s' "$json" | jq -r '.text // empty' 2>/dev/null)
  [ -n "$d" ] && dest=$d
  [ -n "$s" ] && section=$s
  [ -n "$t" ] && text=$t
fi

[ -z "$dest" ] && dest=focus  # safe fallback if the LLM was unreachable

"$hud" capture --dest "$dest" --section "$section" "$text" >/dev/null 2>&1
notify-send -t 4000 "captured → ${dest}" "$text" 2>/dev/null || true
