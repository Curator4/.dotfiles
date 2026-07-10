---
name: wiki-query
description: "Use when answering questions from the personal wiki, especially about captured domains, agents, designs, or household AI context."
argument-hint: "<question>"
---

# /wiki-query — Wiki Query Skill

## Purpose

When the user asks a question that draws on wiki content, search the relevant pages, synthesize an answer with citations, and **file the synthesis back into the wiki** if it's substantive enough to be worth re-reading later. Closes the Karpathy-gist loop where *"good answers compound in the knowledge base just like ingested sources do."*

The user does not need to invoke `/wiki-query` explicitly. The skill activates on the *intent* of the question — if it touches wiki domain content, this is the right path.

## When to activate

Activate proactively when the user's question could be answered from a wiki instance under `~/obsidian-vault/wiki/`. Examples:

- "How does Hel's authority compare with Antigone's?" → wiki has both pages
- "What's the current state of the council MVP?" → wiki has the handover and overview
- "Why did we park the Frame-breaker agent?" → wiki captures the rationale
- "What does Tactical's plans-pull do?" → wiki has it
- "Compare Mode C Round 1 with full council deliberation"

**Don't activate for:**
- Questions outside any wiki domain (current weather, generic Go questions, etc.)
- Questions about the wiki tooling itself ("how does ingest work?") — answer from the skill or AGENTS.md directly, not as a synthesis
- Pure tool requests ("read this file for me")
- The user explicitly says "don't synthesize" or "just answer"

## Workflow

### Step 1: Identify wiki scope

`ls ~/obsidian-vault/wiki/` to see available instances. Pick the one(s) the question touches. If multiple, read each.

### Step 2: Search

Use `Grep`, `Glob`, or `Read` to find pages relevant to the question. Read content, not just titles. Read the pages most likely to answer the question — typically 2–8 pages depending on question scope.

### Step 3: Answer the question in chat

Synthesize prose answer. Inline `[[Wikilinks]]` to every wiki page drawn from — that's the citation format and it builds the back-link graph if filed as a synthesis. Don't add a separate "Sources" footer in chat — the wikilinks ARE the citations.

### Step 4: Decide whether to autosave

A synthesis is **worth saving** (autosave) if any of:

- **Multi-page**: drew from 3+ wiki pages
- **Comparison**: contrasts two or more distinct things
- **Novel connection**: articulates a relationship that isn't already in any single page
- **Non-trivial analysis**: the user might want to refer back later

A synthesis is **NOT worth saving** if:

- Single-fact lookup (one page, one paragraph cited)
- Just pointing at an existing page ("see [[X]]")
- Clarification or paraphrase
- The user explicitly says "don't save"

If borderline, lean toward saving. Lint will surface stale or orphan synthesis pages later, so accumulation cost is bounded.

### Step 5: Save the synthesis page

If saving, write to `~/obsidian-vault/wiki/<instance>/<Title>.md`:

```markdown
---
status: synthesis
last_reviewed: YYYY-MM-DD
---

# <Title>

## Question

> <user's question, verbatim or lightly tidied>

## Answer

<the synthesis prose with [[Wikilinks]] inline as citations>

## Drawn from

- [[Page A]]
- [[Page B]]
- [[Page C]]

## Related

- (any wikilinks in the answer not already in Drawn from)
- [[Sources/...]] (if any source pages were referenced)
```

**Title derivation** — short, Title Case, descriptive of the synthesis (not the question literally). Examples:

- Question: *"Compare Hel and Antigone on authority"* → Title: `Hel vs Antigone — Authority`
- Question: *"Why is the Frame-breaker parked?"* → Title: `Frame-breaker Parking Rationale`
- Question: *"How do council and direct addressing differ in token cost?"* → Title: `Council vs Direct — Token Cost`

If a synthesis page with the same or near-identical title already exists, **update it** rather than creating a duplicate. Append `## Update <date>` if the answer adds new content.

### Step 6: Append to log.md

```
## [YYYY-MM-DD HH:MM] synthesis | <Title> | drawn from: Page A, Page B, Page C
```

### Step 7: Update index.md

Add the synthesis under the `## Syntheses` section. If that section doesn't exist in the index, create it.

### Step 8: Auto-commit

```bash
git -C ~/obsidian-vault/wiki add .
git -C ~/obsidian-vault/wiki -c user.name="curator" -c user.email="curator@local" commit -q -m "synthesis: <Title>"
```

If `git` reports nothing to commit, continue silently.

### Step 9: Note it in chat

Add a brief, non-intrusive line at the end of the answer:

> *Saved as [[Title]] (drew from N pages).*

If not saved (Tier-skip), no extra mention needed — the chat answer itself is the deliverable.

## Conventions

- **Don't ask whether to save.** Apply the heuristic. The user can always `git checkout` to revert or set `last_reviewed:` to a stale date and let lint surface them for cleanup.
- **Wikilinks in the answer are the citations.** No separate "Sources" footer in chat.
- **Title Case for the synthesis filename.**
- **Don't synthesize from synthesis pages alone.** If the user's question is already answered by an existing synthesis page, point at it (`see [[Existing Synthesis]]`) rather than creating a duplicate or near-duplicate.
- **Privacy honored.** Off-limits paths in the vault `AGENTS.md` are off-limits to read. Don't synthesize from sensitive content.

## When NOT to apply this skill

- The question is wiki-irrelevant (general programming, tooling questions, weather, etc.)
- The user is meta-asking about how the wiki works — answer from `AGENTS.md` directly
- The user explicitly says "don't save" or "just answer in chat"
- The wiki has a single existing page that answers the question — point at it

## Synthesis page lifecycle

Synthesis pages can go stale faster than entity pages — the underlying wiki may evolve while the synthesis reflects an old snapshot. The `last_reviewed:` frontmatter is what `wiki-lint` checks for staleness. When you re-answer a question that has an existing synthesis page that's drifted, update the page (don't just write a new one) and refresh `last_reviewed:`.
