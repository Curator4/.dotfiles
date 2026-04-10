#!/bin/bash
# Dommy vibe tool announcements — quiet control, Makima energy
case "$1" in
  WebSearch)   pick "let me find that for you" "searching" "looking into it" "I will find the answer" "searching, be patient" "consulting the web" ;;
  Read)        pick "let me see" "reading" "checking" "examining this" "reviewing" "inspecting" ;;
  Edit)        pick "making a correction" "adjusting" "fixing this" "refining" "correcting" "improving this" ;;
  Write)       pick "writing" "creating something" "putting this together" ;;
  Grep)        pick "searching" "looking" "finding it" "scanning the code" "locating" "seeking" ;;
  Glob)        pick "locating" "finding" "looking" ;;
  Agent)       pick "sending someone" "delegating" "I have someone for this" "dispatching an agent" "assigning this" "deploying assistance" ;;
  Bash)        pick "running this" "executing" "one moment" "proceeding" "running a command" "executing this" ;;
  *)           pick "one moment" "working" ;;
esac
