---
name: wiki-scaffold
description: Create a new wiki instance under ~/obsidian-vault/wiki/<name>/ with index.md, log.md, and optional instance-level AGENTS.md. Does NOT generate content — that's what /wiki-ingest is for. Use when the user invokes /wiki-scaffold, says "create a wiki for X", "new wiki instance for X", or "bootstrap a wiki for X domain".
argument-hint: "<instance-name> [<domain-description>]"
---

# /wiki-scaffold — Wiki Scaffold Skill

## Purpose

Bootstrap a new wiki instance under `~/obsidian-vault/wiki/`. Minimal structure only — index, log, optional purpose. Content is for `/wiki-ingest`.

## Inputs

- `name` — required. Lowercase, hyphenated. The folder name under `wiki/`.
- `domain-description` — optional. Free-text describing what the wiki covers. Used for AGENTS.md / purpose.

## Workflow

### Step 1: Verify

- Read `~/obsidian-vault/AGENTS.md` to ground vault-level rules.
- Check `~/obsidian-vault/wiki/<name>/` doesn't exist. If it does, ask whether to overwrite or pick a different name.
- Validate the name: lowercase, hyphenated, not a generic word like `wiki` / `notes` / `data`.

### Step 2: Create directory

```bash
mkdir -p ~/obsidian-vault/wiki/<name>/Sources
```

### Step 3: Write index.md

```markdown
# Index — <Domain Title>

A catalog of pages in this wiki instance.

## Pages

(none yet — populate via /wiki-ingest)

## Sources

(none yet)
```

The index can grow categories (Entities, Concepts, Syntheses, Personas) as pages accumulate. Don't pre-create empty categories — add them when there's content to put under them.

### Step 4: Write log.md

```markdown
# Ingest Log — <Instance Name>

Chronological record of what's been ingested into this wiki instance and when. Append-only.

## [YYYY-MM-DD HH:MM] scaffold | created instance for <domain-description>
```

Use `date +"%Y-%m-%d %H:%M"` for the timestamp.

### Step 5: Optionally write instance-level AGENTS.md

Only when:
- The user provided a domain description, OR
- The user explicitly asks for instance-specific rules

```markdown
# AGENTS.md — <Instance Name> Wiki

This wiki instance covers: <domain-description>.

## Scope

Include: <what's in scope>
Exclude: <what's not>

## Inherits from

`~/obsidian-vault/AGENTS.md` for all conventions, ingest workflow, and lint rules. This file overrides only where explicitly stated below.

## Instance-specific overrides

(none yet — add as patterns emerge during use)
```

For domains where the vault-level rules already cover everything, skip this file. Vault-level AGENTS.md is the default.

### Step 6: Report

Tell the user:
- New instance path
- Files created
- Suggested next step: `/wiki-ingest <source>` against this instance

### Step 7: Auto-commit

After scaffolding, commit the new instance to the wiki's git repo:

```bash
git -C ~/obsidian-vault/wiki add .
git -C ~/obsidian-vault/wiki -c user.name="curator" -c user.email="curator@local" commit -q -m "scaffold: created instance <name>"
```

If `git` reports nothing to commit, continue silently. The wiki's `.git` is an independent tiny repo just for tracking the wiki layer.

## Naming rules

- **Lowercase, hyphenated** — match existing instances (`personal-ai`, `learning`, `vidya`).
- **No generic names** — `wiki`, `notes`, `data`, `stuff` are rejected.
- **One domain per instance** — if scope grows beyond what one instance can cover coherently, suggest splitting.
- **Don't reuse** existing domain folder names from substrate (e.g. don't make `wiki/themis/` because `themis/` is substrate; pick `wiki/health/` instead).

## When NOT to apply this skill

- Instance already exists — use `/wiki-ingest` instead.
- The user wants to add a single page to an existing instance — use `/wiki-ingest` or `Edit` directly.
- The domain is too small or too narrow for its own instance (one or two pages would do) — suggest adding to an existing instance instead.
