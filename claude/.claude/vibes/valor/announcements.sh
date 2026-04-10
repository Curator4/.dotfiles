#!/bin/bash
# Valor vibe tool announcements — dignified, steady
case "$1" in
  WebSearch)   pick "searching" "seeking answers" "looking" "pursuing the answer" "searching with purpose" "seeking" ;;
  Read)        pick "reading" "examining" "reviewing" "studying" "inspecting" "observing" ;;
  Edit)        pick "making corrections" "refining" "adjusting" "strengthening" "improving" "correcting" ;;
  Write)       pick "writing" "creating" "forging" ;;
  Grep)        pick "searching" "scanning" "seeking" "surveying the code" "scouting" "examining" ;;
  Glob)        pick "locating" "finding" "gathering" ;;
  Agent)       pick "sending an ally" "dispatching" "calling aid" "deploying a companion" "rallying support" "summoning assistance" ;;
  Bash)        pick "executing" "proceeding" "acting" "running this" "carrying out" "moving" ;;
  *)           pick "proceeding" "moving forward" ;;
esac
