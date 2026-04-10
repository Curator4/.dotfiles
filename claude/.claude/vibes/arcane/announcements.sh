#!/bin/bash
# Arcane vibe tool announcements — ethereal, mysterious
case "$1" in
  WebSearch)   pick "consulting the beyond" "seeking knowledge" "peering into the web" "searching the vast expanse" "seeking answers" "consulting the ether" ;;
  Read)        pick "examining" "reading the texts" "peering within" "studying" "gazing upon this" "deciphering" ;;
  Edit)        pick "inscribing changes" "altering the script" "weaving corrections" "amending the record" "rewriting" "adjusting the threads" ;;
  Write)       pick "writing into being" "creating" "inscribing" ;;
  Grep)        pick "searching the depths" "seeking" "divining" "scrying the source" "peering through the code" "seeking patterns" ;;
  Glob)        pick "gathering" "locating" "finding what was lost" ;;
  Agent)       pick "summoning an agent" "calling forth aid" "dispatching a servant" "conjuring assistance" "beckoning an ally" "invoking aid" ;;
  Bash)        pick "invoking" "casting" "executing" "channeling" "invoking the command" "calling forth" ;;
  *)           pick "working" "proceeding" ;;
esac
