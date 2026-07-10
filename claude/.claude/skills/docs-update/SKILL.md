---
name: docs-update
description: "Use when dispatching a background docs update from recent commits, especially at ticket close, /done, or when tech docs need synchronization."
---

# /docs-update

Dispatch the docs-update agent. The dispatch is fire-and-forget — this skill returns the moment the wrapper has acquired its lock and spawned the detached process. Mako notifies on completion or failure.

## When to invoke

- **Auto** — as the docs step inside `/done`, after PR merge / Jira transition / branch cleanup. Default-on; `--skip-docs` opts out.
- **Manual mid-phase** — any time you want docs to catch up to a specific range without waiting for ticket close. Same skill, just dispatched directly.
- The spawned agent self-no-ops on diffs that don't affect any page, so false-positive dispatches are cheap.

## Args

| Arg | Required | Meaning |
|-----|----------|---------|
| `--range` | yes | Git rev range to consume. Examples: `main..HEAD`, `<phase-base>..HEAD`, `<sha>..HEAD`. |
| `--ticket` | yes | Jira/issue key — used only for log/status filenames and notifications. Never appears in docs prose or commit messages. |
| `--intent` | no | 2–3 sentence plain-language orientation for the spawned agent. Scaffolding, not source material. |
| `--crosscutting` | no | Comma-separated list of cross-cutting page paths affected (e.g., `src/architecture.md,src/shutdown.md`). |

## Steps for the invoking agent

1. **Resolve the range.**
   - Per-ticket close (the common case): range is the ticket branch's first commit through HEAD. Use `git merge-base <branch> main` to find the base if unsure.
   - Manual mid-phase: take the range from the operator's intent.
2. **Resolve the ticket key.** Extract from branch name (e.g. `feature/AR-194/behavioral-test-pass` → `AR-194`).
3. **Optionally compose an intent note.** 2–3 sentences in shape-of-system terms — "what this range actually changed in the codebase," not "what this ticket was tracking." Skip if the diff is self-evident.
4. **Optionally identify cross-cutting pages.** Inspect the diff yourself. If a change touches lifecycle, shutdown ordering, the composition root, or other system-wide invariants, list the affected cross-cutting pages. Cross-cutting pages are the ones without `source:` frontmatter (typically `src/architecture.md`, `src/shutdown.md`, `src/routing.md`, `src/forwarding.md` umbrella).
5. **Invoke the wrapper.**
   ```bash
   ~/.agents/skills/docs-update/wrapper.sh \
     --range="$RANGE" \
     --ticket="$TICKET" \
     --intent="$INTENT" \
     --crosscutting="$CROSSCUTTING"
   ```
   Empty `--intent` and `--crosscutting` are fine — pass empty strings or omit.
6. **Report.** One-liner to the user: `📚 dispatched docs-update for $TICKET (range $RANGE) — mako will notify on completion.` Do not wait for the agent.

## Behaviour (what the wrapper does)

- Acquires `flock -n` on `~/.local/state/docs-agent/lock`. If contended, refuses with a "skipped — already running" mako notification and exits 0. The dispatch did not happen; re-fire after the in-flight one completes.
- Notifies dispatch via mako (low urgency, brief).
- Resolves source repo absolute path from `git rev-parse --show-toplevel` at invocation time.
- Resolves docs repo path as `<source-repo>/docs/`. Spawn cwd is set there.
- Spawns detached `Codex -p` with `--permission-mode auto` (model and reasoning inherited from user defaults — xhigh by default).
- Background subshell holds the flock for the duration; foreground exits immediately so the invoking session is unblocked.
- Spawned agent reads `docs/AGENTS.md` for the writing contract, walks commits via `git -C <source>`, edits pages, runs `mdbook build`, commits locally on success, stashes on build failure.
- After agent exits 0, the wrapper itself runs `git push origin main` from the docs repo (operator-authorized, sidesteps auto-mode's restriction on shared-system writes by the agent).
- Final mako notification:
  - `✅ docs agent — $TICKET — docs updated` (normal urgency) on success with commits.
  - `✅ docs agent — $TICKET — no docs change needed` (normal) on agent no-op.
  - `❌ docs agent — $TICKET — failed (rc=N, see $LOG)` (critical, persistent) on agent non-zero or build failure.
  - `❌ docs agent — $TICKET — commit landed locally but push failed` (critical) on push failure.
  - `⏱ docs agent — $TICKET — timed out` (critical) on 10m timeout.

## State files

- Lock: `~/.local/state/docs-agent/lock`
- Status: `~/.local/state/docs-agent/runs/<YYYYMMDD-HHMMSS>-<ticket>.status` (one line: `running` → `done`/`done-noop`/`failed-N`/`timeout`/`push-failed`).
- Log: `~/.local/state/docs-agent/runs/<YYYYMMDD-HHMMSS>-<ticket>.log` (full stdout/stderr from Codex -p plus push output).

To inspect recent runs:
```bash
ls -t ~/.local/state/docs-agent/runs/*.status | head -10 \
  | xargs -I{} sh -c 'printf "%-50s %s\n" "$(basename {} .status)" "$(cat {})"'
```

## Hard rules

- This skill never blocks. If you need to wait for completion, watch mako or tail the log file.
- The contract the spawned agent follows lives in the docs repo at `docs/AGENTS.md` (alongside a `AGENTS.md` symlink for older tools). Voice, page shapes, anti-patterns — all there. Keep that file authoritative.
- Do not pass per-dispatch style guidance to the agent. Style lives in the contract, not in the prompt.
- The intent note is for the agent to *understand with*, not *quote from*. The skill makes this explicit in the prompt template.

## Bootstrap

Initial `docs/AGENTS.md` is hand-written, not skill-generated. The skill assumes it exists. If it doesn't, the spawned agent will likely produce poor output and you should write the contract first (or run a one-shot `Codex -p` with a bootstrap prompt — separate from this skill).

## Files in this skill

- `SKILL.md` — this file.
- `wrapper.sh` — the bash entry point. Owns lock, notifications, spawn, push, status.
- `agent-prompt.md` — the prompt template the wrapper interpolates per-dispatch.
