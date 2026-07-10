#!/usr/bin/env bash
# HUD: a session ended (SessionEnd — incl. /clear) — tombstone it so the board
# drops it immediately instead of waiting for it to age out of the 15m window.
# Async / fire-and-forget — always exit 0.
[ -n "${HUD_SUMMARIZING:-}" ] && exit 0
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
printf 'dead' > "$dir/$sid" 2>/dev/null
exit 0
