#!/usr/bin/env bash
# HUD: mark this Claude Code session "working" for the activity board.
# Bound to PreToolUse + UserPromptSubmit (async, fire-and-forget).
# MUST NOT block or fail a session — always exit 0.
[ -n "${HUD_SUMMARIZING:-}" ] && exit 0   # don't let summary sub-sessions register
[ -n "${HUD_BG:-}" ] && exit 0   # background machinery never registers
input=$(cat 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0
dir="$HOME/.local/state/hud/active"
mkdir -p "$dir" 2>/dev/null
if [[ "${INTER_SESSION_LABEL:-}" == *" channel" ]]; then
  printf 'bg' > "$dir/$sid" 2>/dev/null
  exit 0
fi
printf 'working' > "$dir/$sid" 2>/dev/null
exit 0
