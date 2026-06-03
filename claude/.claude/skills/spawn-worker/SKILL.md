---
name: spawn-worker
description: Spawn a fire-and-forget background Claude Code session that auto-registers with the inter-session bus, bootstrapped with the orchestrator's name and the inter-session reply protocol (done:/status:/question: prefixes). Use when the user invokes /spawn-worker, says "spawn a worker", "dispatch a background session", "delegate to a new session", or wants the orchestrator session to fan out work to child sessions that report back via inter-session messages. Orchestrator-side only — the spawnee receives its bootstrap automatically.
---

# Spawn worker

Fire-and-forget spawner for background Claude Code sessions wired into the inter-session bus. The orchestrator returns immediately with the spawnee's short ID; progress arrives later as inter-session messages.

## Prerequisites

- The orchestrator (this session) must be connected to the bus with an explicit name. If `/inter-session:inter-session status` is unconnected or shows a generic auto-named slot (e.g. `<cwd-basename>` or `<cwd-basename>-<role>`), run `/inter-session:inter-session connect <orch-name>` first.
- The spawnee inherits the orchestrator's cwd and is auto-registered on the bus by the plugin under a cwd-derived name (e.g. `<cwd>-sub-N`). The orchestrator does NOT try to control the spawnee's bus name — it routes replies by parsing a task identity tag (`[<task>]`) from the body. The orchestrator learns the bus-name → task mapping from the first reply's `from=<bus-name>` field.

## Quick start

```
/spawn-worker <name> <task description...>
/spawn-worker --worktree <name> <task description...>   # isolated parallel work
```

Run the helper:

```
Bash("$HOME/.claude/skills/spawn-worker/scripts/spawn.sh [--worktree] <name> <task description>")
```

The script:

1. Parses optional `--worktree` flag.
2. Validates `<name>` against `^[a-z0-9][a-z0-9-]{0,39}$`.
3. Looks up the orchestrator's bus name via inter-session `list.py --self`.
4. If `--worktree`: creates `.worktrees/<name>/` off the orchestrator's current branch (detached HEAD) and cds into it.
5. Builds a bootstrap prompt with spawnee identity, orchestrator name, reply-prefix contract, and (if applicable) workspace info.
6. Runs `claude --bg --name <name> "<prompt>"` and parses the short ID.
7. Prints attach / send / logs / stop commands (plus worktree path + cleanup hint when applicable).

Surface the script's stdout verbatim. Add commentary only if it errored.

## Parallel workers: isolation

Default behavior spawns the worker in the orchestrator's cwd — fine for one worker, or for workers that won't touch files (orientation-only / design-only). When fanning out **multiple workers that will write code**, pass `--worktree`:

```
spawn.sh --worktree gh196 "<task>"
spawn.sh --worktree gh199 "<task>"
```

Each worker lands in `<repo-root>/.worktrees/<name>/` on a detached HEAD at the current branch's tip. The bootstrap tells the worker to `git checkout -b <slice-branch>` before committing. Worktrees don't share working-tree state, so workers can stage, commit, and even rebase independently without colliding.

**Why detached HEAD instead of a fresh branch?** Avoids leftover `worker/<name>` branches accumulating in the repo when workers create their own slice branches anyway (e.g. via `/start-ticket`). The worker's first commit lands on the slice branch it creates, not on the detached worktree HEAD.

**Cleanup**: spawn.sh's stdout shows the `git worktree remove` command. Run it after the worker's PR merges. If `claude --bg` itself fails post-worktree-creation, the script's ERR trap removes the orphaned worktree automatically.

**When to skip `--worktree`**: single workers, orientation-only spawns (worker reads + reports, never edits), or short-lived diagnostic spawns. The flag adds ~1s of overhead and a path on disk; not worth it for non-code tasks.

See also `feedback_agent_worktree_isolation` (memory) for why manual worktree creation is preferred over the `isolation:worktree` Agent parameter.

## What the spawnee receives

The bootstrap prompt is structured as:
1. Identity: spawnee's task name (`<name>`), orchestrator's bus name (`<orchestrator>`)
2. Reply protocol: ALWAYS prefix the body with `[<name>]`, then use `done:` / `status:` / `question:` per the inter-session reaction protocol. Example: `/inter-session:inter-session send <orchestrator> '[<name>] done: result here'`.
3. Task description

The spawnee's bus name (auto-assigned by plugin auto-start) is opaque to the orchestrator at spawn time. The orchestrator extracts the mapping from the first reply: `from=<bus-name>` (inter-session protocol field) + `[<name>]` (task tag in body) → `<name> → <bus-name>`. Subsequent `send` calls from the orchestrator use the bus name; humans referring to "the <name> worker" go through the orchestrator's task-tracking.

## Exit codes

| Code | Meaning | Fix |
| :-- | :-- | :-- |
| 1 | wrong arg count | `spawn.sh <name> <task...>` |
| 2 | invalid name | match `^[a-z0-9][a-z0-9-]{0,39}$` |
| 3 | inter-session plugin not found | reinstall or check `~/.claude/plugins/cache/inter-session/` |
| 4 | orchestrator not connected to bus | `/inter-session:inter-session connect` |
| 5 | `claude --bg` returned no short ID | read script stderr for raw output |
| 6 | `--worktree` outside git repo | cd into a git repo first |
| 7 | worktree path already exists | `git worktree remove <path>` then retry |
| 8 | `--worktree` with detached HEAD at orchestrator | check out a branch in the orchestrator first |

## Why fire-and-forget

Orchestrator stays free to drive other workers or do its own work. Spawnee replies arrive as Monitor stdout lines via the inter-session client — apply the inter-session reaction policy when they show up. Blocking the orchestrator on a worker that might take an hour defeats the parallelism this exists to enable.
