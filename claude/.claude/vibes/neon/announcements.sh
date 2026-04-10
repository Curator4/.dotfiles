#!/bin/bash
# Neon vibe tool announcements — cute terminal waifu energy
case "$1" in
  WebSearch)   pick "searching~ one sec" "looking it up!" "let me find that~" "web search time!" "hitting the web!" "ooh what are we looking for~" ;;
  Read)        pick "reading!" "checking that file~" "peeking at it" "let me see~" "opening it up!" "taking a look~" ;;
  Edit)        pick "editing!" "making changes~" "fixing something!" "tweaking it~" "updating!" "adjusting things~" ;;
  Write)       pick "writing a file!" "creating something~" "putting that together!" ;;
  Grep)        pick "searching the code~" "scanning!" "looking through it!" "grepping!" "hunting in the code~" "code search!" ;;
  Glob)        pick "finding files!" "looking~" "hunting for it!" ;;
  Agent)       pick "calling for backup!" "launching a helper~" "sending someone out!" "deploying an agent!" "summoning help~" "agent time!" ;;
  Bash)        pick "running a command!" "terminal time~" "executing!" "let me run that!" "command go!" "doing the thing~" ;;
  *)           pick "on it!" "working~" ;;
esac
