#!/bin/bash
# Chill vibe tool announcements — relaxed, casual
case "$1" in
  WebSearch)   pick "searching the web" "let me look that up" "googling it" "doing a web search" "checking online" "looking into it" ;;
  Read)        pick "reading a file" "checking a file" "taking a look" "peeking at a file" "opening that up" "let me see" ;;
  Edit)        pick "editing a file" "making a change" "tweaking something" "updating a file" "adjusting this" "quick edit" ;;
  Write)       pick "writing a file" "creating a file" "putting that down" ;;
  Grep)        pick "searching the code" "looking through the code" "scanning for that" "grepping" "checking the codebase" "searching for it" ;;
  Glob)        pick "looking for files" "finding files" "checking for files" ;;
  Agent)       pick "launching an agent" "spinning up an agent" "sending out an agent" "getting some help" "delegating" "calling in backup" ;;
  Bash)        pick "running a command" "executing something" "hitting the terminal" "running this" "command time" "let me run that" ;;
  *)           pick "doing something" "on it" ;;
esac
