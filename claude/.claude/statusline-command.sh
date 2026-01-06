#!/bin/bash

# Read JSON input from stdin
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Change to the working directory
cd "$cwd" 2>/dev/null || true

# Get directory info
if git -c core.filemode=false rev-parse --is-inside-work-tree &>/dev/null; then
  # Inside a git repo - show repo root
  repo_root=$(basename "$(git -c core.filemode=false rev-parse --show-toplevel 2>/dev/null)")
  repo_path=$(git -c core.filemode=false rev-parse --show-prefix 2>/dev/null | sed 's:/$::')
  if [ -n "$repo_path" ]; then
    # We're in a subdirectory
    printf "\033[1;38;2;69;158;81m%s\033[0m\033[38;2;69;158;81m/%s\033[0m " "$repo_root" "$repo_path"
  else
    # We're at repo root
    printf "\033[1;38;2;69;158;81m%s\033[0m " "$repo_root"
  fi
else
  # Not in git repo - show last 2 path components
  path_parts=$(echo "$cwd" | awk -F/ '{
    n = NF
    if (n == 1) print $1
    else if (n == 2) print $1"/"$2
    else print "…/"$(n-1)"/"$n
  }')
  printf "\033[38;2;69;158;81m%s\033[0m " "$path_parts"
fi

# Git branch
git_branch=$(git -c core.filemode=false symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$git_branch" ]; then
  printf "\033[3;38;2;84;158;106m %s\033[0m " "$git_branch"

  # Git status with detailed indicators
  git_status=$(git -c core.filemode=false status --porcelain 2>/dev/null)

  if [ -n "$git_status" ]; then
    status_str=""

    # Check for each type of change
    echo "$git_status" | grep -q '^??' && status_str="${status_str}?"
    echo "$git_status" | grep -q '^ M\|^M \|^MM' && status_str="${status_str}!"
    echo "$git_status" | grep -q '^A \|^AM' && status_str="${status_str}+"
    echo "$git_status" | grep -q '^R ' && status_str="${status_str}»"
    echo "$git_status" | grep -q '^D \|^ D' && status_str="${status_str}✗"

    # Check for stashed changes
    git -c core.filemode=false stash list 2>/dev/null | grep -q . && status_str="${status_str}\$"

    # Check ahead/behind
    ahead_behind=$(git -c core.filemode=false rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
    if [ -n "$ahead_behind" ]; then
      ahead=$(echo "$ahead_behind" | awk '{print $1}')
      behind=$(echo "$ahead_behind" | awk '{print $2}')

      if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        status_str="${status_str}⇕⇡${ahead}⇣${behind}"
      elif [ "$ahead" -gt 0 ]; then
        status_str="${status_str}⇡${ahead}"
      elif [ "$behind" -gt 0 ]; then
        status_str="${status_str}⇣${behind}"
      fi
    fi

    if [ -n "$status_str" ]; then
      printf "\033[38;2;247;107;21m%s\033[0m " "$status_str"
    fi
  fi
fi

# Remove trailing space
printf "\b"
