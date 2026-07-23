#!/usr/bin/env bash
# HUD: surface one posture nudge at a prompt seam. Submitting a prompt is the
# moment the operator has just handed work off and is about to sit idle waiting
# — the one point in the loop where standing up costs them nothing. Nudging
# mid-turn is what they explicitly didn't want.
#
# SYNCHRONOUS (not async): stdout from UserPromptSubmit is added to the session's
# context, and that is the entire delivery mechanism. Always exits 0 — exit 2
# from this event erases the operator's prompt.
#
# All the judgement lives in `hud posture nudge`, which stays silent unless a
# nudge is both due and unclaimed. The claim is the point: without it every live
# session would raise the same nudge on the same turn.
#
# Machinery is never the operator: summary sub-sessions, background crons and
# heartbeats, and inter-session channels all opt out, same as the other hud hooks.
[ -n "${HUD_BG:-}" ] && exit 0
[ -n "${HUD_SUMMARIZING:-}" ] && exit 0
[[ "${INTER_SESSION_LABEL:-}" == *" channel" ]] && exit 0
/home/curator/workspace/hud/hud posture nudge 2>/dev/null
exit 0
