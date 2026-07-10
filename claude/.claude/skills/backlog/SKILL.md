---
name: backlog
description: "Use when the user asks about personal todos, backlog items, ideas, tasks, action items, or wants something added to their list."
argument-hint: "[item to add or action]"
---

# Backlog

The user's personal backlog is Tactical's captured-intent file in the household repo.

## File Location

`/home/curator/workspace/ai/household-oc/agents/tactical/data/backlog.md`

## When to Use

- User asks about their todos, backlog, or task list
- User wants to add/remove items
- User asks "what's on my plate" or similar
- Extracting action items from a conversation

## Reading

Read the file to check current items before responding about tasks. Sections:

- `## Time-sensitive` — deadline-driven; items carry an `@ YYYY-MM-DD` suffix
- `## Personal admin`, `## Home` — categorized working items
- `## Captured` — inbox; not yet filed
- `## Someday` — no checkbox, **not pester-eligible**, low signal

## Updating

This file is LLM-maintained and shared with Tactical, so follow her contract:

- **Adding**: append `- [ ] YYYY-MM-DD <text>` to the end of `## Captured`. Do not
  file it into a category — Tactical re-files `## Captured` at her 23:00 wrap-up.
- **Completing**: remove the line entirely. The backlog is a working set, not an
  archive; her stagnation flagging and deadline tracking assume only active items.
- **Don't write enrichment metadata** (`@ deadline`, `~ last-touched`) — Tactical
  adds those during tidy.
- Don't restructure sections or reorder items.

`/holly <text>` is the dedicated capture/complete path and implements the same
rules with disambiguation; prefer it when the user's intent is a bare capture.

## Scope

- Items here are **todos**. A *knowledge / synthesis* question belongs in the
  LLM-maintained wiki at `~/obsidian-vault/wiki/<instance>/` instead — mention
  `/wiki-query` or `/wiki-ingest` as the better fit.
- A **legacy backlog** lived at `~/obsidian-vault/themis/backlog.md` until
  2026-07-10, when it was deleted as outgrown. Its 106 items were project plans
  (Council MVP, Io briefing, OpenClaw deep dive, local AI infra), not todos.
  If the user asks after something that isn't here, it may be in there:
  `git -C ~/obsidian-vault show 09a3a33~1:themis/backlog.md`
