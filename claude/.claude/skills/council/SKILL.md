---
name: council
description: "Use when the user wants multi-model advice, adversarial code review, council review, cross-model opinions, or several models to weigh in."
argument-hint: "review [--base <ref>] [--scope ...] [focus] | <topic / question / design to put to the council>"
---

# council — multi-model fan-out

Convene a council of independent model engines (Grok, GLM, Codex, Claude) over either the current code changes or an open question, then let a **fresh-context chair** reconcile their input into one report.

**Advisory only.** Never fix issues, apply patches, edit code, or imply you're about to change anything. Your job is to run the pipeline and present its report.

This skill lives at `$HOME/.agents/skills/council/` — resolve `$HOME` to the real absolute path when building `Workflow` calls and companion paths.

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
node "$HOME/.agents/skills/council/scripts/council-companion.mjs" council --json \
  --alias-file /tmp/council/aliases.json $REVIEW_ARGS > /tmp/council/findings.json
```

The companion reviews the diff with each enabled engine and emits compact JSON: `{diff, repoPath, findings:[{engine,severity,title,body,file,line_start,line_end,recommendation}], skipped}`. Engines that are unavailable (quota exhausted, not installed) land in `skipped` — expected graceful degradation, not an error. Engine ids in this JSON are **blinded aliases** (`reviewer-N`) so the chair can't play favorites; the real mapping is written to `/tmp/council/aliases.json` — Read it now (you need it in A3), and don't paste real engine names into anything the workflow's agents will read. If the diff is too large for one prompt, the companion reviews it file-by-file in batches and adds `partial:{batches,totalFiles,reviewedFiles,skippedFiles}` — note this for A4 (it means coverage was partial).

Scope is `--scope auto|working-tree|staged|commit|branch|file` (default `auto`: working tree if dirty, else branch vs `--base`/`main`). Use `--scope staged` to review only what's `git add`ed — i.e. exactly what the next commit would record (pre-commit review); if the user asks to review their staged changes / what they're about to commit, pass `--scope staged`. Use `--scope commit --base <sha>` to review a single commit's diff (vs its parent) without checking it out (default `HEAD`); if the user asks to review a specific commit, pass that. Use `--scope file --base <path>` to review a diff read from a FILE (a saved `.patch`, `gh pr diff` output, a proposed change) instead of a git state — this works even outside a git repo; if the user asks to review a patch/diff file or a PR diff they've fetched, pass that.

**A2 — Short-circuit.** If `diff` is empty or `findings` is empty, tell the user there's nothing to review (and why — all engines skipped, or no diff) and stop. Do not launch the workflow.

**A3 — Synthesize + validate.** Otherwise run the review synthesis workflow (resolve `$HOME` to an absolute path in `scriptPath`):

```
Workflow({
  scriptPath: "<$HOME>/.agents/skills/council/workflows/synthesis.mjs",
  args: {
    findingsFile: "/tmp/council/findings.json",
    repoPath: "<REPO_ROOT from A1>",
    aliases: <the parsed object from /tmp/council/aliases.json>
  }
})
```

The chair reads the findings file, dedupes/merges across reviewers (tagging each finding with the `engines` that raised it, reconciling severity), then fans out validators that check each critical/high finding against the actual code — conservatively dropping only findings they can positively refute. The chair and validators see only the `reviewer-N` aliases; the workflow de-aliases with `aliases` at return time, so the report you get back carries real engine names. It runs in the background and notifies on completion.

**A4 — Present.** When the workflow returns, present its result faithfully (no added review, no fixes):

- Lead with the **verdict** (`needs-attention` / `approve`), a one-glance severity count (e.g. "3 findings — 1 critical, 2 high"; if `dropped` is non-empty, add "N refuted by validation"), and the one-line summary — so a ship-blocker is obvious before reading the list.
- List each finding as `### [SEVERITY] title  [engines]`, then `` `file:line` ``, the body, and **Fix:** the recommendation. Sort critical → low; within a severity, the workflow already lists corroborated (multi-engine) findings before solo ones — preserve that order.
- Mark any finding whose `validated` is `unconfirmed`: the chair's validator could neither reproduce it from the code nor positively refute it — flag it as "unconfirmed — verify manually", so it's not read with the same weight as a `confirmed` one.
- Name the reviewers that actually ran.
- If `dropped` is non-empty, note briefly which findings validation refuted, and why.
- If `confidence` is `low`, say so prominently: the verdict rests on thin evidence — fewer than two reviewers ran, or a `needs-attention` whose strongest finding is a lone, unvalidated claim. Tell the user to verify it before acting, rather than taking the verdict at face value.
- If the companion JSON (A1) included `partial`, say prominently that the diff was too large to review at once: it was reviewed file-by-file in `batches` batches, `reviewedFiles`/`totalFiles` files covered (cross-file issues may be missed), and list any `skippedFiles` that were too large to review at all. Coverage is incomplete — frame the verdict accordingly.

**A5 — Persist.** Always, after presenting: Write the workflow's returned report object to `/tmp/council/report.json`, then save it durably:

```bash
node "$HOME/.agents/skills/council/scripts/council-companion.mjs" save-report /tmp/council/report.json --repo "<REPO_ROOT from A1>"
```

It prints the saved directory — `report.json` + rendered `report.md` under `~/.local/share/council/reports/` (a `latest` symlink tracks the newest). Mention the saved path in one closing line. If the user wants a shareable page, load the `artifact-design` skill and publish the saved `report.md` via the Artifact tool.

**A6 — Machine-readable export (on request).** If the user wants SARIF / CI output (e.g. to upload to GitHub code scanning or gate a build), convert the persisted report — this exports the VALIDATED chair report, not the raw pre-chair findings:

```bash
node "$HOME/.agents/skills/council/scripts/council-companion.mjs" to-sarif /tmp/council/report.json > council.sarif
```

`to-sarif` also accepts `-` to read the report JSON from stdin. severity maps to SARIF level (critical/high → error, medium → warning, low → note); refuted/`dropped` findings are excluded.

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
node "$HOME/.agents/skills/council/scripts/council-companion.mjs" council-brief \
  --brief-file /tmp/council/brief.md --json \
  --alias-file /tmp/council/aliases.json > /tmp/council/takes.json
```

The companion fans the brief out to each enabled engine for an independent **prose** take (no schema — open analysis doesn't fit a findings shape) and emits `{brief, repoPath, takes:[{engine,label,text}], skipped}`. Engines that are unavailable land in `skipped`. Engine ids and labels in the takes are **blinded aliases** (`reviewer-N` / `Reviewer N`) so the chair reconciles arguments, not reputations; the real mapping is written to `/tmp/council/aliases.json` — Read it now (you need it in B3).

**B2 — Short-circuit.** If `takes` is empty (every engine skipped), tell the user the council couldn't convene (and why) and stop.

**B3 — Synthesize.** Otherwise run the open-council synthesis workflow (resolve `$HOME`; pass the repo root or `pwd` as `repoPath`):

```
Workflow({
  scriptPath: "<$HOME>/.agents/skills/council/workflows/council-synth.mjs",
  args: {
    takesFile: "/tmp/council/takes.json",
    repoPath: "<git root or pwd>",
    aliases: <the parsed object from /tmp/council/aliases.json>
  }
})
```

A single fresh-context chair reads the takes and reconciles them neutrally — it wrote none of them, so it isn't anchored on this conversation, and it sees only the blinded `reviewer-N` aliases (the workflow de-aliases at return time, so the report carries real engine names). There's **no validate-against-code stage** here (nothing to validate); that's review-only.

**B4 — Present.** When the workflow returns, present its result faithfully (no added opinion of your own):

- Lead with the **recommendation** and the one-line summary. If the chair flagged the recommendation as its own call rather than unanimous, say so.
- **The crux** — the `crux`: the one fact/assumption/condition that would most change the recommendation. Surface it right after the recommendation; it's the actionable "go find this out before deciding" lever.
- **Where they agree** — the `consensus` points.
- **Where they diverge** — each `divergences` entry: the point, then each stance attributed to the engine(s) that held it. This is the high-value part; don't flatten it.
- **Strongest points** raised by any single member.
- **Open questions** the council couldn't resolve.
- Name the members that actually weighed in (one-line `takes` gist each is a nice touch).

**B5 — Persist.** Always, after presenting: Write the workflow's returned report object to `/tmp/council/report.json`, then save it durably:

```bash
node "$HOME/.agents/skills/council/scripts/council-companion.mjs" save-report /tmp/council/report.json --repo "<git root or pwd>"
```

It prints the saved directory — `report.json` + rendered `report.md` under `~/.local/share/council/reports/` (a `latest` symlink tracks the newest). Mention the saved path in one closing line. If the user wants a shareable page, load the `artifact-design` skill and publish the saved `report.md` via the Artifact tool.

---

## Other modes

- **Quick single-model pass** (Grok alone, no synthesis workflow — fast, free on the SuperGrok sub):
  `node "$HOME/.agents/skills/council/scripts/council-companion.mjs" grok-review $REVIEW_ARGS`
- **Engine status:** `node "$HOME/.agents/skills/council/scripts/council-companion.mjs" setup`

A full review run is ~2–3 min and ~100k–130k tokens (gather + chair + validators); an open council is lighter (gather + one chair, no validators). The Claude member additionally spends Claude Max quota (one headless `claude -p` per council). See `$HOME/.agents/skills/council/README.md` for architecture and engine/auth details.
