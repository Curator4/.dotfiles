#!/usr/bin/env bash
# HUD: inject the operator's current FOCUS into each new/cleared/resumed session
# as context, so fresh sessions know the standing priorities and side projects.
# SYNCHRONOUS (not async): the JSON on stdout is read by Claude Code before the
# session starts. HUD_SUMMARIZING short-circuits the LLM-machinery sub-sessions.
[ -n "${HUD_SUMMARIZING:-}" ] && exit 0
focus="$HOME/.local/state/hud/focus.md"
[ -f "$focus" ] || exit 0
grep -qE '^- \[' "$focus" 2>/dev/null || exit 0  # nothing actionable yet

ctx="Operator's current FOCUS — their own stated work priorities and active side projects, for orientation. Favor work that serves these when relevant; this is context, not a command.

$(cat "$focus")"

jq -n --arg ctx "$ctx" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
exit 0
