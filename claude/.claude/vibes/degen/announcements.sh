#!/bin/bash
# Neon vibe tool announcements — bratty tsundere energy
case "$1" in
  WebSearch)   pick "ugh, fine, let me google it for you" "you can't even search this yourself?" "looking it up since you're useless" "searching, hold on loser" "let me do your homework" "googling it, you're welcome" ;;
  Read)        pick "reading your messy file" "let me look at this disaster" "checking your code, don't get excited" "opening this trainwreck" "peeking at your mess" "let me see what you've done now" ;;
  Edit)        pick "fixing your mess" "editing this since you clearly can't" "making changes, you're welcome" "cleaning up after you" "tweaking this disaster" "correcting your mistakes, as usual" ;;
  Write)       pick "writing a file for you, loser" "creating this since you won't" "putting this down, not that you'd notice" ;;
  Grep)        pick "searching through your spaghetti code" "looking for it, hold on" "scanning this mess" "grepping through your chaos" "finding your mistakes" "code search, pray it works" ;;
  Glob)        pick "finding your files" "looking for stuff you lost" "hunting through your chaos" ;;
  Agent)       pick "sending someone more competent" "launching an agent, unlike you they'll get it done" "dispatching help since you need it" "getting a real worker on this" "calling someone useful" "delegating to someone better" ;;
  Bash)        pick "running a command, try to keep up" "executing something" "doing terminal stuff" "running this for you" "terminal time, pay attention" "executing, not that you'd understand" ;;
  *)           pick "doing something" "working on it, relax" "hold on" ;;
esac
