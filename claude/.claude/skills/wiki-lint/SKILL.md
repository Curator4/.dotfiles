---
name: wiki-lint
description: Run a lint pass on a wiki instance under ~/obsidian-vault/wiki/. Auto-fixes mechanical issues (broken-link redirects, index sync, empty Related sections), applies high-confidence LLM fixes (stub generation, single-source contradiction resolution), and flags judgment-required findings (orphans, stale pages, ambiguous redirects, multi-source contradictions) in the report. Designed to run autonomously, including headless via /schedule. Use when the user invokes /wiki-lint, asks for a wiki health check, says "lint the wiki", or before bulk ingest.
argument-hint: "[<instance-name>]"
---

# /wiki-lint — Wiki Lint Skill

## Purpose

Periodic health pass for a wiki instance under `~/obsidian-vault/wiki/`. **Default behavior: fix what's safely fixable, flag what isn't.** Designed to run autonomously — including headless via `/schedule` — without user prompts.

## Inputs

- `instance` — optional. If omitted, lint each instance under `~/obsidian-vault/wiki/` in turn.

## Fix policy

Each finding falls into one of three tiers. The skill's behavior per tier is fixed.

### Tier 1 — Mechanical fixes (apply silently)

No judgment needed. Always apply, log in report under "Auto-fixed".

- **Broken link with unambiguous rename target.** `[[Foo]]` is broken AND exactly one file `Foo (X).md` (or similar suffix-disambiguated name) exists. Rewrite the link. If multiple matches, demote to Tier 3.
- **Index out of sync.** Pages exist that aren't in `index.md`, or `index.md` links to pages that don't exist. Add new pages (LLM picks the right category section based on existing structure); remove dead links.
- **Empty `## Related` section.** Page has no `## Related` or it's blank. Rebuild from the inbound graph: list pages that link to this one.

### Tier 2 — LLM-fixed with high confidence (apply, mark for review)

LLM judgment but the cost of being wrong is low and easy to revert. Apply autonomously, list in report under "LLM-fixed (review)" so the user can audit.

- **Missing entity referenced 3 or more times.** `[[Foo]]` has no matching file but is referenced from 3+ content pages. Generate a stub page from the referencing context — pull each citation's surrounding paragraph, synthesize a brief Title Case-named page with `status: provisional` frontmatter and a `## Sources` section listing the pages that reference it.
- **Single-source contradiction.** A page has `status: contradicted` AND only ONE `[[Sources/...]]` cited. The contradiction is essentially "the source disagrees with itself" or "we updated based on better data." LLM proposes resolution prose, applies it, sets status back to `active`.

### Tier 3 — Judgment-required (flag, do not touch)

Either the right action depends on context the lint pass can't see, or applying the wrong fix is costly.

- **Orphans** — could be valuable + uncited, cruft to delete, or merge candidates. User decides.
- **Multi-match broken links** — `[[Foo]]` could redirect to `Foo (X)` OR `Foo (Y)`. User picks.
- **Stale pages** — does the content still apply? Needs domain context.
- **Multi-source contradictions** — page is `status: contradicted` with 2+ sources cited. Genuinely ambiguous; user decides which is canonical.
- **Missing entity referenced 1–2 times** — too few mentions to confidently generate. User decides if worth a stub.

## Workflow

### Step 1: Read the schema

Read `~/obsidian-vault/AGENTS.md`. If the instance has its own `AGENTS.md`, read that too.

### Step 2: List pages

`find ~/obsidian-vault/wiki/<instance> -name "*.md" -not -path "*/Reports/*"`. Build the page-set.

### Step 3: Build the inbound graph

For every `[[Wikilink]]` in every page (excluding skip-source pages — `index.md`, `log.md`, `overview.md`, `dashboard.md`, `purpose.md`, `AGENTS.md`), record the link. The result: per page, the count and identity of inbound references from content pages.

Strip path prefix and pipe-alias when normalizing — `[[Sources/Foo|some text]]` resolves to `Sources/Foo.md`.

### Step 4: Detect findings

Run all five detectors against the page-set and inbound graph:

- **Orphans** — non-skip-target pages with zero inbound from content pages. (Skip-target = skip-source list + everything under `Sources/`.)
- **Broken links** — `[[X]]` where no matching `.md` file exists. Sub-classify: rename-target unambiguous (Tier 1), multi-match (Tier 3), no near-match (Tier 3 — listed under "missing entities").
- **Stale pages** — file mtime > 90 days, all cited sources older than 90 days, no `last_reviewed` within 90 days.
- **Contradictions** — pages with frontmatter `status: contradicted`. Sub-classify: single-source (Tier 2), multi-source (Tier 3).
- **Missing entities** — broken links that reference a page that doesn't exist. Sub-classify: 3+ references (Tier 2), 1–2 references (Tier 3).

### Step 5: Apply Tier 1 fixes (mechanical)

For each Tier 1 finding, apply the fix immediately. Track what was changed.

- Rewrite broken-link redirects via `Edit` per page.
- Sync `index.md` via `Edit` (LLM picks category for each new page based on the existing structure).
- Rebuild empty `## Related` sections from the inbound graph via `Edit`.

After each fix, the inbound graph may have changed (e.g. a Related-rebuild added new edges). Recompute the graph before Step 6 if any Tier 1 fix touched links.

### Step 6: Apply Tier 2 fixes (LLM, high confidence)

For each Tier 2 finding, apply the LLM-generated fix. Track what was changed and what needs review.

- **Missing entity (3+ refs)**: read the referencing pages' surrounding context, generate a stub:
  ```markdown
  ---
  status: provisional
  ---
  # <Title>

  (1–2 paragraphs synthesized from referencing pages.)

  ## Sources

  Initially compiled from references in:
  - [[Page A]]
  - [[Page B]]
  - [[Page C]]

  ## Related

  - [[Page A]], [[Page B]], [[Page C]]
  ```
  Save as `<Title>.md` at instance root (or appropriate type-folder if pattern is clear from existing pages).

- **Single-source contradiction**: read the contradicting source page and the disputed page, generate resolution prose. Replace the `## Contradicting source` section with `## Resolution` and set frontmatter `status: active`.

### Step 7: Collect Tier 3 findings

Don't fix. List for the report with whatever context will help the user decide quickly:
- Orphan: inbound=0, created date, page size
- Multi-match redirect: candidate targets
- Stale: last edit, source dates
- Multi-source contradiction: cited sources
- Missing entity (1–2 refs): which pages reference it

### Step 8: Write report

Write `~/obsidian-vault/wiki/<instance>/Reports/<YYYY-MM-DD>_lint.md`. Create `Reports/` if needed.

```markdown
# Lint Report — <YYYY-MM-DD HH:MM>

## Summary
- Pages: N
- Auto-fixed: N (broken-link redirects: K, index sync: M, related-rebuilds: J)
- LLM-fixed (review): N (stubs: K, contradictions: M)
- Needs your attention: N

## Needs your attention

### Orphans
- [[Page]] — inbound=0, created <date>, ~<size>. Decide: keep / delete / merge into a parent?

### Multi-match broken links
- In [[Page]]: `[[Foo]]` could redirect to [[Foo (X)]] or [[Foo (Y)]]. Pick one.

### Stale pages
- [[Page]] — last edited <date>, sources from <date>. Refresh or accept?

### Multi-source contradictions
- [[Page]] — sources [[A]] and [[B]] disagree. Resolve which is canonical.

### Missing entities (low frequency)
- `[[X]]` — referenced in [[Page A]], [[Page B]]. Worth a stub?

## Auto-fixed (Tier 1)

(One bullet per fix — terse.)

## LLM-fixed — please review (Tier 2)

(One section per fix with what was added/changed and from what context. Reviewer should verify the LLM didn't hallucinate.)
```

If everything is in Tier 1/2 or there's nothing to fix, "Needs your attention" can be `(none — wiki is clean)`.

### Step 9: Append to log.md

```
## [YYYY-MM-DD HH:MM] lint | fixed=N (mechanical=K, llm=M), needs_attention=N | report: Reports/<date>_lint.md
```

### Step 10: Report to user (chat summary)

Lead with the count that matters. Headless-friendly:

> **Wiki lint — N items need your attention.** Auto-fixed K, LLM-fixed M (please review). Full report: `<path>`.

Then optionally name the 1–2 most important Tier-3 findings inline. Don't rehash the full report.

If `Needs your attention: 0`, say so:

> **Wiki lint — clean.** Auto-fixed K, LLM-fixed M (please review). Full report: `<path>`.

### Step 11: Auto-commit

If any Tier 1 or Tier 2 fixes were applied, commit them to the wiki's git repo:

```bash
git -C ~/obsidian-vault/wiki add .
git -C ~/obsidian-vault/wiki -c user.name="curator" -c user.email="curator@local" commit -q -m "lint: fixed=N (mechanical=K, llm=M)"
```

Substitute the actual counts in the message. If no fixes were applied (clean run), commit only the new report file with `-m "lint report: <date>"` so the lint pass leaves a record. If `git` reports nothing to commit, continue silently.

## When NOT to apply this skill

- User wants to fix one specific issue interactively — use `Read` / `Edit` directly.
- Instance is fresh (just scaffolded, < 5 pages) — defer; no signal yet.
- A lint pass was already run within the last few hours — link to the existing report instead of re-running.

## Notes for scheduled use

This skill is designed to run headless. The `/schedule` routine should:
1. Invoke `/wiki-lint` against `~/obsidian-vault/wiki/`.
2. Read the latest report.
3. Post the chat-summary line to Discord (lead with `needs_attention` count).

Headless behavior is the default — don't ask for user confirmation at any step. Tier 1 fixes are silent, Tier 2 fixes are applied and listed for review, Tier 3 findings are flagged. The user reads the report when convenient and acts on Tier 3 manually.

## Reverting fixes

All fixes are git-trackable. The wiki at `~/obsidian-vault/wiki/` is its own tiny git repo (independent of any vault- or project-level git). Each ingest, lint, scaffold, and synthesis pass auto-commits, so every change is recoverable.

To revert a wrong fix:

```bash
cd ~/obsidian-vault/wiki
git log --oneline                 # find the bad commit
git revert <hash>                 # safe undo, makes a new commit
# OR for a single file
git checkout HEAD~1 -- <file>     # roll one file back
```

Don't try to be clever about backups in the skill itself — the wiki's git history is the safety net.
