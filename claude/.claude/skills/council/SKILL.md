---
name: council
description: Convene a multi-model council. Two modes. (1) "/council review" runs an adversarial CODE review — fans the current diff out to several model CLIs (Grok, GLM, Codex), then a fresh-context chair dedupes their findings with consensus tags and validates the critical/high ones against the real code. (2) "/council <topic>" gives open-ended ADVICE — fans a design, decision, plan, spec, or question out to the same models for independent takes, then a fresh-context chair synthesizes consensus, disagreements, the strongest points, and a recommendation. Use when the user says "/council", "council", "convene the council", "ask the council", "multi-model" or "cross-model" opinion/review, "get other models' take on this", "review this with multiple models", "adversarial review of my changes", or wants several models to weigh in before a merge or a decision.
argument-hint: "review [--base <ref>] [--scope ...] [focus] | <topic / question / design to put to the council>"
---

# council — multi-model fan-out

Convene a council of independent model engines (Grok, GLM, Codex) over either the current code changes or an open question, then let a **fresh-context chair** reconcile their input into one report.

**Advisory only.** Never fix issues, apply patches, edit code, or imply you're about to change anything. Your job is to run the pipeline and present its report.

This skill lives at `$HOME/.claude/skills/council/` — resolve `$HOME` to the real absolute path when building `Workflow` calls and companion paths.

## Route

Look at the arguments:

- If the first token is **`review`** → run **Mode A — code review**. Drop the `review` token; the rest (`--base` / `--scope` / focus text) are review arguments.
- Otherwise → run **Mode B — open council**, treating the entire argument string as the council's topic.
- If there are **no arguments**: if the working tree has uncommitted changes and the intent looks like reviewing them, offer Mode A; otherwise ask the user what they want the council to weigh in on.

---

## Mode A — code review

Review the current changes with every available engine, then synthesize and validate into one report.

**A1 — Gather.** From the repo under review (the current working directory), capture the repo root, then fan out and write raw findings to a temp file. Substitute the review arguments (everything after the `review` token) where `$REVIEW_ARGS` appears:

```bash
mkdir -p /tmp/council
git rev-parse --show-toplevel    # REPO_ROOT — capture for step A3
node "$HOME/.claude/skills/council/scripts/council-companion.mjs" council --json $REVIEW_ARGS > /tmp/council/findings.json
```

The companion reviews the working-tree (or branch) diff with each enabled engine and emits compact JSON: `{diff, repoPath, findings:[{engine,severity,title,body,file,line_start,line_end,recommendation}], skipped}`. Engines that are unavailable (quota exhausted, not installed) land in `skipped` — expected graceful degradation, not an error.

**A2 — Short-circuit.** If `diff` is empty or `findings` is empty, tell the user there's nothing to review (and why — all engines skipped, or no diff) and stop. Do not launch the workflow.

**A3 — Synthesize + validate.** Otherwise run the review synthesis workflow (resolve `$HOME` to an absolute path in `scriptPath`):

```
Workflow({
  scriptPath: "<$HOME>/.claude/skills/council/workflows/synthesis.mjs",
  args: { findingsFile: "/tmp/council/findings.json", repoPath: "<REPO_ROOT from A1>" }
})
```

The chair reads the findings file, dedupes/merges across reviewers (tagging each finding with the `engines` that raised it, reconciling severity), then fans out validators that check each critical/high finding against the actual code — conservatively dropping only findings they can positively refute. It runs in the background and notifies on completion.

**A4 — Present.** When the workflow returns, present its result faithfully (no added review, no fixes):

- Lead with the **verdict** (`needs-attention` / `approve`) and the one-line summary.
- List each finding as `### [SEVERITY] title  [engines]`, then `` `file:line` ``, the body, and **Fix:** the recommendation. Sort critical → low.
- Name the reviewers that actually ran.
- If `dropped` is non-empty, note briefly which findings validation refuted, and why.

---

## Mode B — open council

Put an open question — a design, a decision between options, a plan, a spec, anything — to the council for independent takes, then synthesize.

**B1 — Assemble the brief.** This is your job (you have the conversation and file access; the companion is just plumbing). Write a **self-contained** brief to `/tmp/council/brief.md` capturing everything a fresh model needs with no other context:

- The actual question or decision, stated plainly. If it's a choice, name the options.
- The relevant context: read any files the user referenced and include the pertinent parts; fold in the design/plan text under discussion; state constraints, goals, and what's already been ruled out and why.
- What kind of judgment you want (a recommendation, risks, a critique of the framing, etc.).

Keep it faithful and neutral — don't bias the council toward an answer. If the brief points at code, mention the repo path so members can read it.

```bash
mkdir -p /tmp/council
# (write the brief to /tmp/council/brief.md with the Write tool, then:)
node "$HOME/.claude/skills/council/scripts/council-companion.mjs" council-brief --brief-file /tmp/council/brief.md --json > /tmp/council/takes.json
```

The companion fans the brief out to each enabled engine for an independent **prose** take (no schema — open analysis doesn't fit a findings shape) and emits `{brief, repoPath, takes:[{engine,label,text}], skipped}`. Engines that are unavailable land in `skipped`.

**B2 — Short-circuit.** If `takes` is empty (every engine skipped), tell the user the council couldn't convene (and why) and stop.

**B3 — Synthesize.** Otherwise run the open-council synthesis workflow (resolve `$HOME`; pass the repo root or `pwd` as `repoPath`):

```
Workflow({
  scriptPath: "<$HOME>/.claude/skills/council/workflows/council-synth.mjs",
  args: { takesFile: "/tmp/council/takes.json", repoPath: "<git root or pwd>" }
})
```

A single fresh-context chair reads the takes and reconciles them neutrally — it wrote none of them, so it isn't anchored on this conversation. There's **no validate-against-code stage** here (nothing to validate); that's review-only.

**B4 — Present.** When the workflow returns, present its result faithfully (no added opinion of your own):

- Lead with the **recommendation** and the one-line summary. If the chair flagged the recommendation as its own call rather than unanimous, say so.
- **Where they agree** — the `consensus` points.
- **Where they diverge** — each `divergences` entry: the point, then each stance attributed to the engine(s) that held it. This is the high-value part; don't flatten it.
- **Strongest points** raised by any single member.
- **Open questions** the council couldn't resolve.
- Name the members that actually weighed in (one-line `takes` gist each is a nice touch).

---

## Other modes

- **Quick single-model pass** (Grok alone, no synthesis workflow — fast, free on the SuperGrok sub):
  `node "$HOME/.claude/skills/council/scripts/council-companion.mjs" grok-review $REVIEW_ARGS`
- **Engine status:** `node "$HOME/.claude/skills/council/scripts/council-companion.mjs" setup`

A full review run is ~2–3 min and ~100k–130k tokens (gather + chair + validators); an open council is lighter (gather + one chair, no validators). See `$HOME/.claude/skills/council/README.md` for architecture and engine/auth details.
