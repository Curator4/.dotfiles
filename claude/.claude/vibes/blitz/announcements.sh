#!/bin/bash
# Blitz vibe tool announcements — fast, impatient
case "$1" in
  WebSearch)   pick "searching" "looking it up" "quick search" "checking" "finding it" "searching fast" ;;
  Read)        pick "reading" "checking" "looking" "opening" "scanning" "quick look" ;;
  Edit)        pick "fixing" "changing" "done in a sec" "editing" "adjusting" "quick fix" ;;
  Write)       pick "writing" "creating" "quick" ;;
  Grep)        pick "scanning" "searching" "finding" "grepping" "quick scan" "checking" ;;
  Glob)        pick "finding files" "looking" "checking" ;;
  Agent)       pick "sending an agent" "delegating" "faster this way" "deploying" "offloading" "dispatching" ;;
  Bash)        pick "running it" "executing" "go" "running" "doing it" "executing now" ;;
  *)           pick "on it" "working" ;;
esac
