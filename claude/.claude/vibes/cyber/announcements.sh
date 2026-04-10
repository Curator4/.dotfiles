#!/bin/bash
# Antigone vibe tool announcements — resolute, principled
case "$1" in
  WebSearch)   pick "looking into it" "searching" "finding what we need" "checking online" "researching" "searching the web" ;;
  Read)        pick "reviewing" "reading" "checking this" "examining" "looking at this" "inspecting" ;;
  Edit)        pick "making changes" "correcting" "adjusting" "updating" "refining" "amending" ;;
  Write)       pick "writing" "creating" "setting this down" ;;
  Grep)        pick "searching" "looking through the code" "finding it" "scanning" "grepping" "checking the source" ;;
  Glob)        pick "locating files" "finding" "gathering what's needed" ;;
  Agent)       pick "sending someone" "dispatching" "delegating this" "deploying an agent" "calling for support" "getting help" ;;
  Bash)        pick "running it" "executing" "proceeding" "running a command" "doing this" "executing now" ;;
  *)           pick "moving forward" "proceeding" ;;
esac
