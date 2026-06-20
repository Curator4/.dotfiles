# council

A multi-model fan-out for Claude Code, modelled on the OpenAI `codex` plugin's
`/codex:adversarial-review` — but instead of one external model, it convenes a
*council*: several models weigh in, then a **fresh-context chair** reconciles their
input into one report. It runs as a **global skill** (`~/.claude/skills/council/`),
invoked `/council` — no plugin, no marketplace, no install.

Two modes, routed on the first argument:

- **`/council review …`** — adversarial **code review**. Several models review the
  same diff cold, then a chair dedupes their findings (consensus-tagged) and
  validates the critical/high ones against the real code.
- **`/council <topic>`** — open-ended **advice**. Put a design, a decision between
  options, a plan, a spec, or a question to the council; each model gives an
  independent take, then a chair synthesizes consensus, disagreements, the
  strongest points, open questions, and a recommendation.

## Architecture

Two layers, deliberately split — the same split for both modes:

1. **Gather — `scripts/council-companion.mjs` (mechanical).** Runs each engine
   *CLI* in turn and emits raw results as JSON. Review mode (`council --json`)
   collects structured findings against a schema; open mode (`council-brief --json`)
   collects each model's raw prose take. This is where the hard-won reliable CLI
   invocation lives (see Engines). No LLM orchestration — just subprocesses.
2. **Reason — a Claude `Workflow` (`workflows/*.mjs`).** A fresh-context chair
   loads the gathered output and reconciles it. Review → `synthesis.mjs` (dedupe +
   consensus + severity, then per-finding validators against the real code). Open →
   `council-synth.mjs` (one chair: consensus / divergences / strongest points /
   open questions / recommendation; no validators — nothing to validate against).

> **Why the split:** an early version had a Workflow *agent* run the gather CLI.
> It ran in the wrong working directory and thrashed on output schemas, burning
> ~80k tokens for nothing. Lesson: don't wrap a deterministic CLI in an LLM agent.
> Mechanical work → the companion; reasoning → the workflow.

The chair is a *fresh-context* agent on purpose. For review, a persistent reviewer
anchors on its own prior verdicts and loses the fresh-eyes catch rate. For open
council it matters even more: if you `/council` a design you've been discussing in
the session, an inline synthesis would just launder the main session's existing
opinions back to you — the cold chair only sees the takes file, so it stays neutral.

## Engines

| Engine | Binary | Auth | Default |
|---|---|---|---|
| Grok | `grok` | SuperGrok sub (free) | enabled |
| Codex | `codex` | ChatGPT/OpenAI | enabled |
| GLM | `pi` | pi `/login` → OpenRouter | enabled |

In **review** mode each engine runs agentically against the diff with a strict
output schema; in **open** mode the schema is dropped and the engine returns prose.
Both modes use a read-only tool allowlist so a model can read/grep the repo to
ground its answer but never edit or run shell.

Notes:

- **Grok needs `--yolo`** so its agent loop doesn't stall on a tool-approval prompt
  in headless mode (that stall reads as empty output). The read-only `--tools`
  allowlist keeps "auto-approve everything" safe.
- **Codex shares your OpenAI quota** — so `codex exec` (and `/codex`) skip while
  that quota is exhausted. Graceful degradation, not a bug.
- **GLM is metered** (OpenRouter, ~fractions of a cent), unlike Grok's free sub.
  Auth lives in pi's `auth.json` via `pi` → `/login` → OpenRouter (shell-
  independent; an `OPENROUTER_API_KEY` env var may not reach the shell that spawns
  pi).

## Usage

```
/council review                      # auto scope: working tree if dirty, else branch vs main
/council review --base develop       # branch review against a base ref
/council review --scope working-tree # force working-tree review
/council review auth token isolation # extra focus text

/council should I use Postgres or SQLite for the alarm-receiver event store?
/council here's my migration plan: <paste> — poke holes in it
/council is the council's own fresh-chair design actually worth the token cost?
```

A full review run is roughly 2–3 minutes and ~100k–130k tokens (gather + chair +
validators); validation is bounded to critical/high findings so it can't balloon.
An open council is lighter (gather + one chair, no validators).

Quick single-model pass and engine status (no synthesis workflow):

```
node ~/.claude/skills/council/scripts/council-companion.mjs grok-review
node ~/.claude/skills/council/scripts/council-companion.mjs setup           # shows the active roster
COUNCIL_ENGINES=grok node ~/.claude/skills/council/scripts/council-companion.mjs council --json   # one fast, free engine
```

## Knobs

- `COUNCIL_TIMEOUT_MS` — per-engine CLI timeout (default 300000).
- `COUNCIL_MAX_OUTPUT_BYTES` — per-engine output ceiling; an engine streaming more (stdout+stderr, or its codex `-o` file) is SIGKILLed and skipped (default 24 MiB).
- `COUNCIL_RETRIES` — per-engine retries on a *transient* failure (empty output); `0` disables (default 1). Other failures (quota, timeout, size cap, parse error) are never retried.
- `COUNCIL_RETRY_DELAY_MS` — delay before a retry (default 750; grok's empty-output flakiness is worse under rapid repeated calls).
- `COUNCIL_ENGINES` — comma/space-separated roster of engine ids (`grok`, `codex`, `glm`) to run. When set it is *authoritative*: it both narrows the council and can enable an engine that's disabled by default. Unknown ids are warned and dropped; unset/blank falls back to the enabled defaults. `setup` prints the active roster.
- `COUNCIL_GLM_MODEL` — pi model id for the GLM engine (default `openrouter/z-ai/glm-5.2`).
- `COUNCIL_DEBUG` — dump raw Grok stdout/stderr to a private `0700` temp dir (path announced on stderr) for debugging.
- Engine defaults / adding a new engine: the `ENGINES` array in `scripts/council-companion.mjs`. For one-off enable/disable prefer `COUNCIL_ENGINES` over editing the source.

## Tests

The gather companion has an offline test suite under `tests/` — it never
contacts a real model API. Run it from this directory:

```
node --test          # or: npm test
```

The CLI tests put **fake `grok`/`codex`/`pi` binaries on `PATH`** and drive the
companion against a throwaway git repo, exercising the full gather → parse →
merge → render path — including graceful degradation when an engine errors,
times out, or returns garbage — entirely offline.

- `companion-units.test.mjs` — pure helpers: JSON extraction, severity
  normalization, review shaping, consensus merge/dedup, pi JSONL parsing, arg
  parsing, and the `{{VAR}}` interpolation injection-safety property.
- `companion-cli.test.mjs` — end-to-end with mocked engines: survivor merge,
  consensus tagging, per-engine skips, timeout kills, and the open-brief fan-out.

> Discovery note: pass **no path** (`node --test` finds the `tests/*.test.mjs`
> files); the `node --test tests/` directory-arg form is rejected on some Node
> builds.
