#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: spawn.sh [--worktree] <name> <task description...>
  --worktree: create .worktrees/<name>/ off the current branch (detached HEAD)
              and spawn the worker inside it. Recommended for parallel workers
              that will write code. Requires being inside a git repo.
  <name>:     ^[a-z0-9][a-z0-9-]{0,39}$
  <task>:     free-form text passed to the spawnee as its initial prompt
USAGE
}

worktree=0
if [[ "${1:-}" == "--worktree" ]]; then
  worktree=1
  shift
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

name="$1"
shift
task="$*"

if ! [[ "$name" =~ ^[a-z0-9][a-z0-9-]{0,39}$ ]]; then
  echo "invalid name '$name': must match ^[a-z0-9][a-z0-9-]{0,39}$" >&2
  exit 2
fi

list_py=$(ls "$HOME"/.claude/plugins/cache/inter-session/inter-session/*/skills/inter-session/bin/list.py 2>/dev/null | sort -V | tail -1)
if [[ -z "$list_py" || ! -f "$list_py" ]]; then
  echo "inter-session list.py not found under ~/.claude/plugins/cache/inter-session/" >&2
  exit 3
fi

orchestrator=$(python3 "$list_py" --self 2>/dev/null | grep -oP '^name=\K\S+' || true)
if [[ -z "$orchestrator" ]]; then
  echo "orchestrator not connected to inter-session bus" >&2
  echo "run: /inter-session:inter-session connect" >&2
  exit 4
fi

spawn_cwd="$PWD"
worktree_path=""
repo_root=""
current_branch=""
if [[ $worktree -eq 1 ]]; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -z "$repo_root" ]]; then
    echo "--worktree requires a git repository; '$PWD' is not inside one" >&2
    exit 6
  fi
  worktree_path="$repo_root/.worktrees/$name"
  if [[ -e "$worktree_path" ]]; then
    echo "worktree path already exists: $worktree_path" >&2
    echo "remove it first: git -C '$repo_root' worktree remove '$worktree_path'" >&2
    exit 7
  fi
  current_branch=$(git -C "$repo_root" branch --show-current || true)
  if [[ -z "$current_branch" ]]; then
    echo "--worktree: current HEAD is already detached; check out a branch first" >&2
    exit 8
  fi
  echo "creating worktree at $worktree_path (detached at $current_branch HEAD)" >&2
  git -C "$repo_root" worktree add --detach "$worktree_path" "$current_branch" >&2
  spawn_cwd="$worktree_path"
  trap 'echo "spawn failed; removing orphaned worktree $worktree_path" >&2; git -C "$repo_root" worktree remove --force "$worktree_path" 2>/dev/null || true' ERR
fi

prompt="You are background session \"$name\" spawned by orchestrator \"$orchestrator\".

You're on the inter-session bus under an auto-assigned name (something like \"<cwd>-sub-N\"). The orchestrator routes replies by parsing a task identity tag from the body — so ALWAYS prefix replies with [$name]:
  /inter-session:inter-session send $orchestrator '[$name] done: <result>'
  /inter-session:inter-session send $orchestrator '[$name] status: <update>'
  /inter-session:inter-session send $orchestrator '[$name] question: <question>'

Task:
$task"

if [[ $worktree -eq 1 ]]; then
  prompt="$prompt

Workspace: you are running in an isolated git worktree at $worktree_path (detached HEAD at $current_branch). Create your slice branch with \`git checkout -b <slice-branch>\` before committing. Cleanup of this worktree happens after merge."
fi

cd "$spawn_cwd"
output=$(claude --bg --name "$name" "$prompt" 2>&1)
short_id=$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -oP 'backgrounded · \K[0-9a-f]+' | head -1)

if [[ -z "$short_id" ]]; then
  echo "spawn failed; claude --bg output:" >&2
  printf '%s\n' "$output" >&2
  exit 5
fi

trap - ERR

cat <<EOF
spawned: $name (id: $short_id) from orchestrator: $orchestrator
EOF
if [[ $worktree -eq 1 ]]; then
  cat <<EOF
  worktree: $worktree_path (detached at $current_branch HEAD)
  cleanup: git -C "$repo_root" worktree remove $worktree_path  (after work merges)
EOF
fi
cat <<EOF
  attach: claude attach $short_id
  send:   /inter-session:inter-session send <bus-name> "..."  (bus name = from-field of first [$name] reply)
  logs:   claude logs $short_id
  stop:   claude stop $short_id
EOF
