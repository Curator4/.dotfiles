#!/bin/bash
# Morose vibe tool announcements — heavy, sorrowful
case "$1" in
  WebSearch)   pick "searching... for something" "looking it up" "maybe the answer is out there" "searching the web" "looking" "checking online i guess" ;;
  Read)        pick "reading" "looking at this" "opening another file" "checking this" "let me see" "reading another one" ;;
  Edit)        pick "changing something" "editing... again" "making corrections" "adjusting" "fixing things" "more edits" ;;
  Write)       pick "writing" "putting words somewhere" "creating... something" ;;
  Grep)        pick "searching" "looking through it all" "scanning" "grepping" "looking for something" "searching the code" ;;
  Glob)        pick "finding files" "looking" "they're here somewhere" ;;
  Agent)       pick "sending someone else" "delegating" "maybe they'll do better" "launching an agent" "getting help" "calling someone" ;;
  Bash)        pick "running something" "executing" "here goes" "running a command" "terminal" "doing this" ;;
  *)           pick "working" "continuing" ;;
esac
