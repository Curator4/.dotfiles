#!/bin/sh
# SessionStart: tell the session voice is on, only when the TTS daemon is up.
# Plain stdout from a SessionStart hook is added to the session's context.
# Replaces the always-on "responses are read aloud" sentence in the working
# agreements (dropped 2026-10-07): true only when the socket exists.
[ -S /tmp/tts-daemon.sock ] || exit 0
[ -f "$HOME/.claude/tts-enabled" ] || exit 0
printf 'Voice is on: replies are read aloud by TTS. Prose first, light formatting, no mood tags.\n'
exit 0
