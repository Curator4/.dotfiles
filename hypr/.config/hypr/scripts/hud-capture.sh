#!/usr/bin/env bash
# Quick-capture, bound to Super+Y. Brain-dump a note in rofi; one Haiku pass
# routes it (BACKLOG + section, or today's ITINERARY) and tidies it — filing
# happens at input time, no inbox pass later. Focus is managed
# conversationally via the `hud` MCP tools — not here — so there are no
# prefixes: just dump and it files.
set -uo pipefail

hud=/home/curator/.bin/hud
claude=/home/curator/.local/bin/claude
llmdir="$HOME/.local/state/hud/llm"
model="claude-haiku-4-5-20251001"

# Leave any modal submap (backlog/checks cards) first: an active submap
# consumes its bound keys globally, so j/k/x/y/t typed into the rofi entry
# below would be eaten mid-word.
hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true

text=$(rofi-ask 'backlog' 'add something…') || exit 0
text=$(printf '%s' "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
[ -z "$text" ] && exit 0

# Haiku routes the note in one pass: dest, section, and tidied text. Filing
# at input time — the old two-stage capture→nightly-tidy died with Tactical
# (ADR 0008); a section costs nothing when a call is already being paid for.
mkdir -p "$llmdir" 2>/dev/null
prompt="Route a captured note and tidy it into a short item.
Destinations:
- itinerary: a time-bound thing for TODAY (appointment, errand, \"watch the game 19:00\").
- backlog: anything else to do later — task, bug, feature, errand. Pick its section by the deliverable:
  time — deadline-driven; a hard date or explicit deadline wording.
  errands — resolved away from the keyboard, or with money: orders, renewals, appointments, chasing humans, subscriptions.
  learn — the deliverable is knowing: primers, courses, evals, comparisons, research, curation.
  build — the deliverable is something made or changed on this machine: code, config, tooling, agents, hardware, wiring.
  inbox — genuinely unsure (rare).
Torn between learn and build: ends in wiring it in → build; ends in understanding → learn. When unsure between backlog and itinerary, choose backlog.
Return ONLY minified JSON: {\"dest\":\"backlog|itinerary\",\"section\":\"time|errands|learn|build|inbox\",\"text\":\"<tidied item>\"}.
Note: $text"

json=$(cd "$llmdir" && HUD_SUMMARIZING=1 "$claude" -p --model "$model" "$prompt" 2>/dev/null |
  tr -d '\n' | grep -o '{.*}' | head -1)
dest=$(printf '%s' "$json" | jq -r '.dest // empty' 2>/dev/null)
section=$(printf '%s' "$json" | jq -r '.section // empty' 2>/dev/null)
tidied=$(printf '%s' "$json" | jq -r '.text // empty' 2>/dev/null)
# A model that echoes the prompt's literal placeholder ("<tidied item>") or
# returns nothing must not poison the file — keep the raw note instead.
case "$tidied" in
*'<tidied'* | *'<'*' item'*'>'*) ;;
*) [ -n "$tidied" ] && text=$tidied ;;
esac
case "$dest" in backlog | itinerary) ;; *) dest=backlog ;; esac             # never focus
case "$section" in time | errands | learn | build) ;; *) section="" ;; esac # unknown → Captured

args=(--dest "$dest")
[ "$dest" = backlog ] && [ -n "$section" ] && args+=(--section "$section")
"$hud" capture "${args[@]}" "$text" >/dev/null 2>&1
label=$dest${section:+/$section}
notify-send -t 4000 "captured → ${label}" "$text" 2>/dev/null || true

# Re-arm a card that is still open, so its modal keys work again without a
# re-toggle.
open=$(eww active-windows 2>/dev/null || true)
case "$open" in
backlog:*) hyprctl dispatch 'hl.dsp.submap("backlog")' >/dev/null ;;
checks:*) hyprctl dispatch 'hl.dsp.submap("checks")' >/dev/null ;;
esac
