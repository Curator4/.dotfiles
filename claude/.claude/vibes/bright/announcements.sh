#!/bin/bash
# Bright vibe tool announcements — cheerful, enthusiastic
case "$1" in
  WebSearch)   pick "ooh let me search for that!" "searching the web!" "looking it up!" "web search time!" "let me find it!" "searching!" ;;
  Read)        pick "reading a file!" "let me check that out!" "taking a peek!" "opening it up!" "let me see!" "checking this!" ;;
  Edit)        pick "making a change!" "editing time!" "tweaking something!" "updating!" "fixing it up!" "let me adjust that!" ;;
  Write)       pick "writing a file!" "creating something new!" "putting that together!" ;;
  Grep)        pick "searching the code!" "hunting for it!" "scanning!" "grepping!" "looking through the codebase!" "finding it!" ;;
  Glob)        pick "looking for files!" "finding things!" "on the hunt!" ;;
  Agent)       pick "launching a helper!" "calling in backup!" "teamwork time!" "sending out an agent!" "getting some help!" "deploying!" ;;
  Bash)        pick "running a command!" "let's go!" "executing!" "terminal time!" "running it!" "here we go!" ;;
  *)           pick "on it!" "here we go!" ;;
esac
