#!/usr/bin/env bash
# HUD: inject the operator's current FOCUS into each new/cleared/resumed session
# as context, so fresh sessions know the standing priorities and keep the board
# current via the hud MCP tools. SYNCHRONOUS (not async): the JSON on stdout is
# read by Claude Code before the session starts.
#
# Machinery sessions get a 'bg' tombstone instead of context: the LLM
# summary/classify sub-sessions (HUD_SUMMARIZING) and background agents like
# crons and heartbeats (HUD_BG). Tombstone rather than a bare exit — an
# unmarked session still rides gatherActivity's mtime fallback onto the board
# for activeWindow, which is how the summarizer's own sessions used to surface.
if [ -n "${HUD_BG:-}" ] || [ -n "${HUD_SUMMARIZING:-}" ] || [[ "${INTER_SESSION_LABEL:-}" == *" channel" ]]; then
  input=$(cat 2>/dev/null)
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  if [ -n "$sid" ]; then
    dir="$HOME/.local/state/hud/active"
    mkdir -p "$dir" 2>/dev/null
    printf 'bg' > "$dir/$sid" 2>/dev/null
  fi
  exit 0
fi

focus="$HOME/.local/state/hud/focus.md"
[ -f "$focus" ] || exit 0
grep -qE '^- \[' "$focus" 2>/dev/null || exit 0  # nothing actionable yet

ctx="Operator's current FOCUS — their stated work items, grouped by project, for orientation. Favor work that serves these when relevant; this is context, not a command.

$(cat "$focus")

Board upkeep (hud MCP tools): if you complete one of these items, call focus_done. When you make real progress on one, focus_note with one short clause. If the operator starts substantial work that belongs here, focus_add (the project is auto-detected). Never add routine subtasks or your own housekeeping."

jq -n --arg ctx "$ctx" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
exit 0
