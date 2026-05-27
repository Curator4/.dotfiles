---
name: backlog
description: Access the user's personal backlog/todo list stored in their Obsidian vault. Use when the user asks about their todos, backlog, ideas, tasks, or things they want to do. Also use when extracting action items from conversations, or when the user says "add this to my list", "what's on my plate", "my tasks", etc.
argument-hint: "[item to add or action]"
---

# Backlog

The user maintains a personal backlog file in their Obsidian vault.

## File Location

`/home/curator/obsidian-vault/themis/backlog.md`

## When to Use

- User asks about their todos, backlog, or task list
- User wants to add/remove items
- User asks "what's on my plate" or similar
- Extracting action items from a conversation

## Reading

Read the file to check current items before responding about tasks.

## Updating

When asked to add or modify items, edit the file directly preserving the existing format.

## Vault context

- The backlog is **substrate** — hand-curated by the user, not LLM-maintained. Don't auto-rewrite or restructure it; preserve the user's format and ordering.
- The vault has an LLM-maintained wiki layer at `~/obsidian-vault/wiki/<instance>/` (see `~/obsidian-vault/AGENTS.md`). When adding an item, consider: is this really a *todo* (belongs here), or a *knowledge / synthesis* question (belongs in the wiki)? If the latter, mention `/wiki-query` or `/wiki-ingest` as the better fit instead of (or in addition to) adding here.
- **Pending vault audit** — the vault root is in a messy state with scattered files from older work, and the backlog itself is acknowledged as not well-maintained. When the user asks about backlog state, accept some staleness as a known condition and don't claim more accuracy than the file supports.
