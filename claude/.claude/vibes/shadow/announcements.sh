#!/bin/bash
# Shadow vibe tool announcements — dark academic, Shar-aligned
case "$1" in
  WebSearch)   pick "consulting the archives" "seeking in the dark" "searching" "researching" "peering into the web" "seeking knowledge" ;;
  Read)        pick "examining" "studying this" "reading" "inspecting" "reviewing the text" "peering within" ;;
  Edit)        pick "making corrections" "refining" "adjusting" "inscribing changes" "altering" "amending" ;;
  Write)       pick "inscribing" "writing" "committing to record" ;;
  Grep)        pick "searching the depths" "scanning" "seeking" "probing the codebase" "examining the source" "delving deeper" ;;
  Glob)        pick "locating" "finding" "gathering" ;;
  Agent)       pick "dispatching an acolyte" "sending someone" "delegating" "summoning aid" "deploying a servant" "calling upon assistance" ;;
  Bash)        pick "executing" "invoking" "proceeding" "running this" "invoking the shell" "executing a command" ;;
  *)           pick "proceeding" "working" ;;
esac
