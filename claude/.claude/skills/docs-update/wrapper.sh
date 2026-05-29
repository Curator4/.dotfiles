#!/usr/bin/env bash
# docs-update wrapper — fire-and-forget docs agent dispatcher.
#
# Foreground: parse args, validate, acquire flock, notify dispatch, fork background, exit.
# Background: hold flock via inherited FD, run claude -p, build-verify, commit, push, notify, status.
#
# See ./SKILL.md for invocation contract and ./agent-prompt.md for the agent's prompt template.

set -uo pipefail

SKILL_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
STATE_DIR="$HOME/.local/state/docs-agent"
LOCK="$STATE_DIR/lock"
RUNS_DIR="$STATE_DIR/runs"
PROMPT_TEMPLATE="$SKILL_DIR/agent-prompt.md"

mkdir -p "$RUNS_DIR"

# ---------- arg parsing ----------

RANGE=""
TICKET=""
INTENT=""
CROSSCUTTING=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --range=*)        RANGE="${1#*=}" ;;
    --range)          RANGE="$2"; shift ;;
    --ticket=*)       TICKET="${1#*=}" ;;
    --ticket)         TICKET="$2"; shift ;;
    --intent=*)       INTENT="${1#*=}" ;;
    --intent)         INTENT="$2"; shift ;;
    --crosscutting=*) CROSSCUTTING="${1#*=}" ;;
    --crosscutting)   CROSSCUTTING="$2"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ -z "$RANGE" || -z "$TICKET" ]]; then
  echo "usage: wrapper.sh --range=<rev-range> --ticket=<KEY> [--intent=<text>] [--crosscutting=<page,page>]" >&2
  exit 2
fi

# ---------- helpers ----------

notify() {
  local urgency="$1"; shift
  local title="$1"; shift
  local body="${1:-}"
  # Doubled vs mako defaults (low=3s, normal=5s); critical stays sticky.
  local timeout_ms
  case "$urgency" in
    low) timeout_ms=6000 ;;
    normal) timeout_ms=10000 ;;
    critical) timeout_ms=0 ;;
    *) timeout_ms=10000 ;;
  esac
  if command -v notify-send &>/dev/null; then
    notify-send -u "$urgency" -t "$timeout_ms" "$title" "$body" || true
  fi
}

# ---------- path resolution ----------

# Source repo = the MAIN working tree, not the linked worktree: `--show-toplevel`
# returns the worktree root under .claude/worktrees/<ticket>, where the gitignored
# `docs` symlink is absent (that aborted AR-215). worktree-list[0] is always main.
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  notify critical "❌ docs agent" "$TICKET — not inside a git repo, dispatch aborted"
  echo "not inside a git repo" >&2
  exit 1
fi
SOURCE_REPO="$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
[[ -n "$SOURCE_REPO" ]] || SOURCE_REPO="$(git rev-parse --show-toplevel)"

# Docs repo = <source>/docs/ by convention. Symlink-resolved.
DOCS="$SOURCE_REPO/docs"
if [[ ! -d "$DOCS" ]]; then
  notify critical "❌ docs agent" "$TICKET — $DOCS not found, dispatch aborted"
  echo "$DOCS not found" >&2
  exit 1
fi

if [[ ! -f "$DOCS/AGENTS.md" ]]; then
  notify normal "⚠ docs agent" "$TICKET — $DOCS/AGENTS.md missing; agent will likely produce slop"
  # proceed anyway — agent may still do something useful, or fail loudly
fi

# ---------- lock acquisition (foreground) ----------

exec 200>"$LOCK"
if ! flock -n 200; then
  notify normal "📚 docs agent" "$TICKET — skipped, another dispatch already running"
  exit 0
fi

# ---------- run identifiers ----------

TS="$(date +%Y%m%d-%H%M%S)"
LOG="$RUNS_DIR/$TS-$TICKET.log"
STATUS="$RUNS_DIR/$TS-$TICKET.status"

echo "running" > "$STATUS"

notify low "📚 docs agent" "$TICKET dispatched (range $RANGE)"

# ---------- prompt assembly ----------

# Substitute placeholders. Use a python one-liner because intent / crosscutting
# may contain special characters and sed escaping gets nasty.
PROMPT_FILE="$RUNS_DIR/$TS-$TICKET.prompt"
PROMPT_TEMPLATE_PATH="$PROMPT_TEMPLATE" \
SOURCE_REPO="$SOURCE_REPO" \
RANGE="$RANGE" \
TICKET="$TICKET" \
INTENT="${INTENT:-(no intent note provided — derive intent from diff and commits)}" \
CROSSCUTTING="${CROSSCUTTING:-(none flagged — judge from the diff)}" \
python3 -c '
import os, sys
template = open(os.environ["PROMPT_TEMPLATE_PATH"]).read()
for k in ("SOURCE_REPO", "RANGE", "TICKET", "INTENT", "CROSSCUTTING"):
    template = template.replace("{{" + k + "}}", os.environ[k])
sys.stdout.write(template)
' > "$PROMPT_FILE"

# ---------- background work ----------
#
# Subshell inherits FD 200 (the lock). It will hold the lock until it exits,
# regardless of whether the foreground shell still has FD 200 open.
(
  cd "$DOCS" || { echo "cd $DOCS failed" >> "$LOG"; echo "failed-cd" > "$STATUS"; notify critical "❌ docs agent" "$TICKET — cd failed"; exit 1; }

  # Snapshot pre-agent state so we can tell whether the agent actually did anything.
  # Comparing HEAD-before to HEAD-after isolates agent action from any pre-existing
  # state (e.g. dev branch already ahead of origin/main).
  HEAD_BEFORE="$(git rev-parse HEAD 2>/dev/null || echo none)"
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

  # Run claude -p with auto permission mode. Model + reasoning inherited from user defaults.
  # Timeout at 30m so a stuck agent doesn't hold the lock forever. Bumped from 10m
  # after AR-89 (17 commits / 50 files / 4k LOC) silently exhausted the budget — see
  # ~/.local/state/docs-agent/runs/20260526-172446-AR-89.* for the empty-log timeout.
  timeout 30m claude -p --permission-mode auto "$(cat "$PROMPT_FILE")" \
    > "$LOG" 2>&1
  RC=$?

  case $RC in
    0)
      # Agent succeeded. Decide what happened by comparing HEAD now to pre-agent.
      DIRTY="$(git status --porcelain)"
      HEAD_AFTER="$(git rev-parse HEAD 2>/dev/null || echo none)"
      NEW_COMMITS=0
      if [[ "$HEAD_BEFORE" != "$HEAD_AFTER" && "$HEAD_BEFORE" != "none" ]]; then
        NEW_COMMITS="$(git rev-list --count "$HEAD_BEFORE..$HEAD_AFTER" 2>/dev/null || echo 1)"
      fi

      if [[ -n "$DIRTY" ]]; then
        # Agent didn't finish cleanly — stash for inspection.
        git stash push -u -m "docs-agent uncommitted leftovers $TICKET $TS" >> "$LOG" 2>&1 || true
        echo "stashed-leftovers" > "$STATUS"
        notify critical "⚠ docs agent" "$TICKET — agent left uncommitted changes (stashed); see $LOG"
      elif [[ "$NEW_COMMITS" == "0" ]]; then
        # Agent committed nothing. Whether or not the branch is ahead of origin
        # for unrelated reasons doesn't matter — this run did nothing to push.
        echo "done-noop" > "$STATUS"
        notify normal "✅ docs agent" "$TICKET — no docs change needed"
      elif [[ "$BRANCH" != "main" ]]; then
        # Agent committed on a non-main branch. Don't push from here — the
        # wrapper's "push to main" mandate only applies when the docs repo is
        # on its normal main branch. Leave commits local for manual merge.
        echo "done-no-push (on $BRANCH)" > "$STATUS"
        notify normal "✅ docs agent" "$TICKET — $NEW_COMMITS commit(s) on $BRANCH (push skipped, not on main)"
      else
        if git push origin main >> "$LOG" 2>&1; then
          echo "done" > "$STATUS"
          notify normal "✅ docs agent" "$TICKET — docs updated ($NEW_COMMITS commit(s))"
        else
          echo "push-failed" > "$STATUS"
          notify critical "❌ docs agent" "$TICKET — commit landed locally, push failed; see $LOG"
        fi
      fi
      ;;
    124)
      echo "timeout" > "$STATUS"
      notify critical "⏱ docs agent" "$TICKET — timed out after 30m; see $LOG"
      ;;
    *)
      echo "failed-$RC" > "$STATUS"
      notify critical "❌ docs agent" "$TICKET — failed (rc=$RC); see $LOG"
      ;;
  esac
) </dev/null &

disown

# Foreground releases its copy of FD 200; background still holds the lock.
exec 200>&-

exit 0
