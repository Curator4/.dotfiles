#!/usr/bin/env bash
# HUD: on turn end, mark this session idle and (debounced + recursion-guarded)
# kick a background summary refresh. Async / fire-and-forget — always exit 0.
[ -n "${HUD_SUMMARIZING:-}" ] && exit 0
[ -n "${HUD_BG:-}" ] && exit 0   # background machinery never registers
input=$(cat 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0

dir="$HOME/.local/state/hud/active"
mkdir -p "$dir" 2>/dev/null
printf 'idle' > "$dir/$sid" 2>/dev/null

# Debounce: skip the LLM refresh if this session's cache was written < 45s ago.
cache="$HOME/workspace/ai/household-oc/agents/shared/cc-sessions/$sid.md"
if [ -f "$cache" ]; then
  mtime=$(stat -c %Y "$cache" 2>/dev/null || echo 0)
  [ "$(( $(date +%s) - mtime ))" -lt 45 ] && exit 0
fi

# Fire-and-forget summary refresh, fully detached (setsid). HUD_SUMMARIZING=1
# makes the summary's own claude -p Stop hook short-circuit (no recursion).
# Run from the tool dir so its claude -p transcript lands in a project dir the
# HUD activity view filters out.
ccp="$HOME/workspace/ai/household-oc/tools/cc-projection"
setsid bash -c "cd '$ccp' && HUD_SUMMARIZING=1 python3 cc-projection.py --session '$sid' \
  && /home/curator/workspace/hud/hud reconcile --session '$sid'" >/dev/null 2>&1 &
exit 0
