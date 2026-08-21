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

# -l 0 is an input box, not a list. Hide listview/mode-switcher so the
# card shrinks to the entry and stays visually centered.
text=$(printf '' | rofi -dmenu -p 'capture +' -l 0 \
    -theme-str 'listview { enabled: false; } mode-switcher { enabled: false; }') || exit 0
text=$(printf '%s' "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
[ -z "$text" ] && exit 0

# Haiku routes the note in one pass: dest, section, and tidied text. Filing
# at input time — the old two-stage capture→nightly-tidy died with Tactical
# (ADR 0008); a section costs nothing when a call is already being paid for.
mkdir -p "$llmdir" 2>/dev/null
prompt="Route a captured note and tidy it into a short item.
Destinations:
- itinerary: a time-bound thing for TODAY (appointment, errand, \"watch the game 19:00\").
- backlog: anything else to do later — task, bug, feature, errand. Pick its section:
  time — deadline-driven; a hard date or explicit deadline wording.
  admin — the operator's personal items: errands, money, subscriptions, learning, research, curation.
  home — the machine and household: system, hardware, rice, keybinds, tooling, agents, anything that is code/config on this box.
  inbox — genuinely unsure (rare).
Torn between admin and home: touch code or config on this machine → home. When unsure between backlog and itinerary, choose backlog.
Return ONLY minified JSON: {\"dest\":\"backlog|itinerary\",\"section\":\"time|admin|home|inbox\",\"text\":\"<tidied item>\"}.
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
case "$dest" in backlog | itinerary) ;; *) dest=backlog ;; esac  # never focus
case "$section" in time | admin | home) ;; *) section="" ;; esac # unknown → Captured

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
