#!/bin/sh
# hud Focus stop gate, for Claude Code and Codex, on Stop.
#
# If this session sits on a board tile, has worked at least HUD_REMINDER_AFTER
# seconds in its current stretch, and the project's Focus stamp has not moved
# since that stretch began, block the stop once with an instruction to update
# Focus (or to say in one line why the board is already current).
#
# Reuses hud-focus-reminder.sh's state line in $HUD_REMINDER_DIR/<session>:
#   START LAST PROJECT STAMP SETTLED
# At most once per session (marker file <session>.stopped). Fail-open: any
# error, missing tool, or unreadable state exits 0 and never wedges a session.
#
# NOT WIRED BY DEFAULT. To enable, add to Stop:
#   ~/.claude/settings.json  hooks.Stop: {"type":"command","command":"~/.claude/hooks/hud-focus-stop.sh","timeout":10}
#   ~/.codex/hooks.json      hooks.Stop: {"type":"command","command":"/home/curator/.claude/hooks/hud-focus-stop.sh","timeout":10}
# Claude Code treats exit 2 + stderr as "block and show the model this text".
# Verify Codex's Stop-hook exit semantics once before relying on it there.
[ -n "${HUD_SUMMARIZING:-}" ] && exit 0
[ -n "${HUD_BG:-}" ] && exit 0
case "${INTER_SESSION_LABEL:-}" in *" channel") exit 0 ;; esac

hud=${HUD_BIN:-hud}
command -v jq >/dev/null 2>&1 || exit 0
command -v "$hud" >/dev/null 2>&1 || exit 0
after=${HUD_REMINDER_AFTER:-600}
gap=${HUD_REMINDER_GAP:-1200}
dir=${HUD_REMINDER_DIR:-${XDG_RUNTIME_DIR:-/tmp}/hud-focus-reminder}

input=$(cat 2>/dev/null) || exit 0
fields=$(printf '%s' "$input" | jq -r '
  [.session_id // "", .cwd // "", .agent_id // "", ((.stop_hook_active // false) | tostring)] | @tsv
' 2>/dev/null) || exit 0
sid=$(printf '%s' "$fields" | cut -f1)
cwd=$(printf '%s' "$fields" | cut -f2)
agent=$(printf '%s' "$fields" | cut -f3)
active=$(printf '%s' "$fields" | cut -f4)
# A subagent's stop is not the session's stop; a second pass after a block lets go.
[ -n "$agent" ] && exit 0
[ "$active" = true ] && exit 0
[ -n "$cwd" ] || exit 0
case "$sid" in ''|*[!A-Za-z0-9_-]*) exit 0 ;; esac
[ "${#sid}" -le 128 ] || exit 0

file="$dir/$sid"
marker="$dir/$sid.stopped"
[ -r "$file" ] || exit 0
[ -e "$marker" ] && exit 0

start='' last='' project='' was='' settled=''
read -r start last project was settled <"$file" 2>/dev/null || exit 0
case "$start" in ''|*[!0-9]*) exit 0 ;; esac
case "$last" in ''|*[!0-9]*) exit 0 ;; esac
[ -n "$project" ] || exit 0
[ "$project" = - ] && exit 0          # directory is on no board

now=$(date +%s)
[ $((now - last)) -le "$gap" ] || exit 0   # the stretch is not current
[ $((now - start)) -ge "$after" ] || exit 0  # too short to owe an update

here=$("$hud" focus stamp --cwd "$cwd" 2>/dev/null | head -n 1)
[ -n "$here" ] || exit 0
[ "$here" = "$project $was" ] || exit 0    # Focus moved (by anyone): nothing owed

: >"$marker" 2>/dev/null || exit 0
mins=$(( (now - start) / 60 ))
printf 'hud: this session worked %s min on %s and its Focus did not change. Add the outcome item and its steps, tick what is done, and save your stopping point (hud-publish skill), or say in one line why the board is already current. Then stop.\n' "$mins" "$project" >&2
exit 2
