---
name: wiki-ingest
description: Ingest a source (vault path, URL, or pasted content) into a wiki instance under ~/obsidian-vault/wiki/. Reads source, decides create/update/flag/skip per entity-and-concept, writes pages with wikilinks, appends to log, updates index. Skips silently if the source content is unchanged since last ingest (hash dedup). Use when the user invokes /wiki-ingest, says "ingest X into the wiki", "compile X into the wiki", or "add this source to the wiki".
argument-hint: "<source-path-or-url> [<instance-name>]"
---

# /wiki-ingest — Wiki Ingest Skill

## Purpose

Ingest a source into an LLM-maintained wiki instance under `~/obsidian-vault/wiki/`. Vault-level rules live at `~/obsidian-vault/AGENTS.md` — read it first.

## Inputs

- `source` — required. A vault path, an absolute path, a URL, or pasted content.
- `instance` — optional. The wiki instance under `~/obsidian-vault/wiki/<instance>/`. If omitted, infer from content or ask.

## Workflow

### Step 1: Read the schema

Read `~/obsidian-vault/AGENTS.md` to ground the rules: substrate paths, wiki paths, off-limits paths, conventions (Title Case, wikilinks, no type taxonomy, frontmatter only when queryable).

If `~/obsidian-vault/wiki/<instance>/AGENTS.md` exists, read that too — it can override or extend vault-level rules.

### Step 2: Resolve the source

- **Vault or absolute file path** — use `Read`.
- **URL** — use `WebFetch`.
- **Pasted content** — use as-is.

Reject sources under off-limits paths (credentials, work-confidential, operational). If the source is sensitive (medical, family), respect the privacy tier.

### Step 3: Identify the target instance

If `instance` arg given, use it. Otherwise infer from source content. If unclear, ask before proceeding. If the instance directory doesn't exist, suggest `/wiki-scaffold` first — don't auto-create.

### Step 4: Hash check (dedup)

Compute SHA-256 of the resolved source content via Bash:

```bash
# File path
sha256sum "<absolute-path>" | cut -d' ' -f1

# URL or pasted content — pipe the bytes through sha256sum
printf '%s' "<content>" | sha256sum | cut -d' ' -f1
```

Grep the instance's `log.md` for that hash:

```bash
grep -F "sha256:<hash>" ~/obsidian-vault/wiki/<instance>/log.md
```

If a matching line is found AND at least one of the pages it lists under `touched:` still exists, **skip and exit**:

> Source unchanged since last ingest at `<timestamp from matched log entry>`. Nothing to do.

Otherwise (hash not found, OR found but pages were since deleted), continue. Edited sources naturally have a different hash and proceed normally — the FLAG/UPDATE/CREATE rules handle the new content.

This dedup is silent and automatic. It does NOT block updates; it only prevents wasted LLM calls when a source hasn't actually changed since the last ingest.

### Step 5: Survey what exists

List pages in the instance: `find ~/obsidian-vault/wiki/<instance> -name "*.md" -not -path "*/Reports/*"`. Read a few of the most relevant ones to know what's already covered.

### Step 6: Analyze the source

Identify:
- **Entities** — people, projects, systems, places (candidates for entity pages)
- **Concepts** — patterns, decisions, designs, ideas (candidates for concept pages)
- **Summary** — 1–3 sentences of what the source is and says
- **Relevance** — does this fit the instance's scope? If not, skip and tell the user.

### Step 7: Apply ingest rules in priority order

For each entity / concept identified, apply rules in order. **The order matters** — flag beats update beats create.

**RULE 1 — FLAG.** If the source DISPUTES or argues against a claim in an existing page, mark that page. Add `status: contradicted` to its frontmatter and append a `## Contradicting source` section quoting the dispute and citing `[[Sources/<source-name>]]`. Never silently overwrite a disputed claim.

**RULE 2 — UPDATE.** If the source adds new information about a subject already covered, and there's no factual dispute, append a new section (`## From <source-name>`) with the new content. Use `[[Wikilinks]]` to other pages. Refresh the page's `## Related` section if needed.

**RULE 3 — CREATE.** Only if the source covers a subject not in any existing page. Title Case filename. Body should:
- Start with `# Page Title`
- Be prose-first, not bullets-only
- Include `[[Wikilinks]]` to related existing pages
- End with `## Related` listing connected wikilinks and source citations

**SKIP.** If the source is out of scope per the instance's rules, log skip reason and stop.

### Step 8: Write the source page

If the source is external (URL or non-vault file), write `~/obsidian-vault/wiki/<instance>/Sources/<Source Name>.md`:

```markdown
# Source — <Title>

## Origin
<vault path or URL>

## Ingested
<YYYY-MM-DD>

## Type
<one or two sentence type description>

## Summary
<1–3 sentence summary>

## Pages touched
- [[Page1]], [[Page2]], ...

## Related
- [[Sources/Other Source]]  (if related)
```

If the source is a vault file already in substrate (e.g. `personal-ai/household.md`), write a short Sources page that *points at* the substrate path rather than duplicating its content.

### Step 9: Append to log.md

Use the current local time (`date +"%Y-%m-%d %H:%M"`) and include the source hash from Step 4:

```
## [YYYY-MM-DD HH:MM] ingest:source | <Source Name> | sha256:<hash> | touched: Page1, Page2, ...
```

The `sha256:<hash>` field is the dedup key for future ingests of the same source. Don't omit it.

### Step 10: Update index.md

If new pages were created, add wikilinks to them under the appropriate section of `index.md`. Match the existing structure — group by category (Personas, Concepts, Syntheses, Sources). Don't invent a new top-level section unless the existing ones don't fit.

### Step 11: Regenerate Overview (if ≥5 pages touched)

If this ingest touched **5 or more pages** (created + updated + flagged), regenerate the auto-overview at `~/obsidian-vault/wiki/<instance>/Overview.md`:

1. List content pages in the instance, excluding `index.md`, `log.md`, `AGENTS.md`, `Overview.md` itself, and anything under `Reports/`.
2. Sort by mtime descending. Take the top 10.
3. For each, capture title and a 1–2 sentence excerpt from the page body.
4. Generate a 2-paragraph summary:
   - **Paragraph 1**: what topics the wiki currently covers
   - **Paragraph 2**: key themes and concepts emerging from the most recent activity
5. Write `Overview.md` with this shape:

```markdown
---
status: auto
updated: YYYY-MM-DD
---

# <Instance Name> — Overview

(2-paragraph auto-generated summary)

---

*Auto-generated on every ingest that touches ≥5 pages. Hand-edit other pages, not this one — manual edits here will be overwritten on the next regen. For a curated synthesis, use a descriptively-named page elsewhere in the instance (e.g. `Household Design Overview` for personal-ai).*
```

If `Overview.md` doesn't exist yet, create it. Add `[[Overview]]` to `index.md` under `## Syntheses` (top of the section) if not already there.

**Skip this step if fewer than 5 pages were touched** — the regen LLM cost isn't justified for small ingests, and the existing Overview is still recent enough.

This page is intentionally lightweight and lossy. Curated synthesis pages stay user-controlled and live elsewhere — the regen never touches them.

### Step 12: Report

Tell the user:
- Pages created (with paths)
- Pages updated (with paths and what was added)
- Pages flagged (with paths and the contradiction)
- Whether anything was skipped and why
- Source page location
- Touched-page count
- Whether the Overview was regenerated

### Step 13: Auto-commit

After a successful ingest, commit the changes to the wiki's git repo:

```bash
git -C ~/obsidian-vault/wiki add .
git -C ~/obsidian-vault/wiki -c user.name="curator" -c user.email="curator@local" commit -q -m "ingest: <Source Name>"
```

Substitute `<Source Name>` with the actual source (e.g. `Council MVP Handover`). If `git` reports nothing to commit, continue silently. The wiki's `.git` is an independent tiny repo just for tracking the wiki layer — not connected to any vault-level git, separate from any project repos.

## Conventions (must follow)

- **Title Case filenames** — `Council Pattern.md`, not `council-pattern.md` or `councilPattern.md`.
- **Wikilinks throughout** generated content — every reference to a thing with its own page should be `[[Page Name]]`.
- **`## Related`** at the bottom of every page, listing connected pages and source citations.
- **Frontmatter only when queryable** — `privacy:`, `last_reviewed:`, `status:` when needed. Never `type: entity`. Pages are pages.
- **Disambiguate name collisions** — if the proposed page name already exists at vault root or in another folder, add a parenthetical suffix (e.g. `Io (Persona).md`).

## Slug / title blacklist

Reject these as page titles — URL artifacts or generic non-topics:
`watch`, `embed`, `video`, `index`, `page`, `post`, `article`, `content`, `wiki`, `wikilinks`, `obsidian`, `dataview`. Pick a meaningful title from the source content instead.

## When NOT to apply this skill

- The user is editing a specific wiki page directly (use `Read` / `Edit`, not ingest).
- The source is sensitive (credentials, work-confidential, medical) — refuse and tell the user.
- The instance doesn't exist and the user hasn't authorized scaffolding it — ask first.

(Re-ingesting the same source: handled automatically by the Step 4 hash check. Same content → silent skip; edited content → normal flow.)
