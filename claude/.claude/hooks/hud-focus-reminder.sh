#!/bin/sh
# hud's Focus reminder (#72), for Claude Code and Codex, on UserPromptSubmit
# and PostToolUse. When a session on a board tile has been working a while
# and its project's Focus hasn't changed since that stretch of work began, it
# adds one line to the agent's next step pointing at the checklist rule in
# the hud-publish skill. Once per stretch, never at session start, quiet
# whenever Focus moves, and silent on any failure.
#
# A stretch begins at a prompt, or at the first step after a long quiet
# spell. Its state is one line per session in $HUD_REMINDER_DIR:
#   START LAST PROJECT STAMP SETTLED
# SETTLED is 1 once the stretch needs nothing more: reminded, Focus moved,
# or the directory is on no board.
#
# Rehearsal knobs: HUD_BIN (the hud to ask), HUD_REMINDER_DIR,
# HUD_REMINDER_AFTER (seconds of work before a reminder, default 600) and
# HUD_REMINDER_GAP (seconds of quiet that start a new stretch, default 1200).
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
  [.hook_event_name // "", .session_id // "", .cwd // "", .agent_id // "",
   (.tool_input.command // "" | if type == "array" then join(" ") else tostring end)] | @tsv
' 2>/dev/null) || exit 0
event=$(printf '%s' "$fields" | cut -f1)
sid=$(printf '%s' "$fields" | cut -f2)
cwd=$(printf '%s' "$fields" | cut -f3)
agent=$(printf '%s' "$fields" | cut -f4)
command=$(printf '%s' "$fields" | cut -f5-)
# A subagent's steps belong to its parent's stretch.
[ -n "$agent" ] && exit 0
[ -n "$cwd" ] || exit 0
case "$sid" in ''|*[!A-Za-z0-9_-]*) exit 0 ;; esac
[ "${#sid}" -le 128 ] || exit 0

mkdir -p "$dir" 2>/dev/null || exit 0
file="$dir/$sid"
now=$(date +%s)

save() { # START LAST PROJECT STAMP SETTLED
  tmp=$(mktemp "$dir/.$sid.XXXXXX" 2>/dev/null) || return 0
  printf '%s %s %s %s %s\n' "$@" >"$tmp" 2>/dev/null && mv -f "$tmp" "$file" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
}

# Where the project's Focus stands now: "SLUG STAMP", or nothing when the
# directory is on no board or hud can't say.
stamp() {
  "$hud" focus stamp --cwd "$cwd" 2>/dev/null | head -n 1
}

begin() { # SETTLED-if-no-board
  here=$(stamp)
  if [ -z "$here" ]; then
    save "$now" "$now" - - 1
  else
    # shellcheck disable=SC2086 # "SLUG STAMP" splits into two fields
    save "$now" "$now" $here "$1"
  fi
}

# The agent writing its own Focus is keeping up. Only the command it ran
# counts, not a tool's output, so reading the skill isn't a write.
writes_focus() {
  printf '%s' "$command" | grep -Eq '(^|[^[:alnum:]_-])hud[[:space:]]+focus[[:space:]]+(add|done|rename|remove)([[:space:]]|$)'
}

if [ "$event" = UserPromptSubmit ]; then
  begin 0
  exit 0
fi
[ "$event" = PostToolUse ] || exit 0

start='' last='' project='' was='' settled=''
[ -r "$file" ] && read -r start last project was settled <"$file" 2>/dev/null
case "$start" in ''|*[!0-9]*) start= ;; esac
case "$last" in ''|*[!0-9]*) start= ;; esac
if [ -z "$start" ] || [ $((now - last)) -gt "$gap" ]; then
  if writes_focus; then begin 1; else begin 0; fi
  exit 0
fi
if [ "$settled" = 1 ] || writes_focus; then
  save "$start" "$now" "$project" "$was" 1
  exit 0
fi
if [ $((now - start)) -lt "$after" ]; then
  save "$start" "$now" "$project" "$was" 0
  exit 0
fi

save "$start" "$now" "$project" "$was" 1
here=$(stamp)
[ "$here" = "$project $was" ] || exit 0
line="hud: you have been working a while and $project's Focus has not changed since you started. If this task has more than one step, add one item for the outcome and two to six steps under it now, and tick each step as you finish it (hud-publish skill, Focus). Reuse an accurate item, keep other agents' items, and add nothing for a one-step task."
jq -nc --arg line "$line" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $line}}' 2>/dev/null
exit 0
