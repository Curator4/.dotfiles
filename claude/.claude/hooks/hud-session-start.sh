#!/usr/bin/env bash
# HUD: inject the operator's current FOCUS into each new/cleared/resumed session
# as context, so fresh sessions know the standing priorities and keep the board
# current via the hud MCP tools. SYNCHRONOUS (not async): the JSON on stdout is
# read by Claude Code before the session starts. HUD_SUMMARIZING short-circuits
# the LLM-machinery sub-sessions; HUD_BG tombstones background agents (crons,
# heartbeats) so the board never shows them.
[ -n "${HUD_SUMMARIZING:-}" ] && exit 0

if [ -n "${HUD_BG:-}" ]; then
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
