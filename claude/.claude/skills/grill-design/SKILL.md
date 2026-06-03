---
name: grill-design
description: "Architectural checkpoint gate. Forces an explicit decision summary and user sign-off before closing tickets, merging architectural PRs, or making irreversible structural changes. Use proactively before any of: closing a Jira ticket as Won't Do, merging a PR that changes module boundaries, swapping a service's transport/storage/coordination model, deleting or restructuring a directory tree."
---

# Grill Design — Architectural Checkpoint

Use this BEFORE taking architecturally significant or irreversible action — not as a post-hoc justification.

## When to invoke

Trigger whenever any of these is about to happen:

- Closing a Jira ticket as Won't Do / Won't Fix
- Merging a PR that changes a module boundary, public API, or storage schema in a non-additive way
- Restructuring a directory tree, renaming a package, or extracting/inlining a service
- Swapping the underlying mechanism of a system (transport, coordination, persistence, scheduler)
- Picking a default that downstream callers will be hard to change later

If you're unsure whether something qualifies, run the skill — false positives cost a minute, false negatives cost a re-do.

## Steps

1. **State the decision precisely.** One sentence. "I'm about to X" — concrete, not "improve Y".

2. **List the alternatives considered.** At least two. If you considered only one, you didn't grill — go consider the other one before continuing.

3. **For each alternative, name the tradeoff.** What does picking the recommended option cost? What does it foreclose?

4. **Name what becomes hard to reverse.** Specifically: which files/branches/tickets/services would need to be touched to undo this in a week? In a month?

5. **Offer a cross-vendor sanity check.** If the decision involves a code diff (not a pure scoping/closure call), ask the user once: "Want me to run `/codex:adversarial-review` against the diff before you sign off?" If yes, run it and fold findings into the decision summary. If no, or no clear answer, skip — proceed to step 6. Don't auto-run. Don't re-ask if declined.

6. **STOP.** Do not execute. Wait for explicit approval from the user. "Looks good" / "go" / "ship it" = approved. Silence ≠ approval. A correction or new question = back to step 1 with the new info.

7. **Only after approval, execute.** If the user approves with caveats, restate the decision incorporating the caveats before moving.

## What this is NOT

- Not a justification template — don't reach the conclusion first and back-fill alternatives.
- Not a tax on every PR — only architectural / irreversible calls. A bugfix or feature within an existing module doesn't need this.
- Not a substitute for `/grill-with-docs` or `/design-ticket` — those are for upfront design. This is the final gate before you commit the design.

## Reference

This skill exists because of a recurring friction pattern: Claude closing AR-72 Phase 0 tickets without checkpointing, applying clean_gone patches mid-discussion, proposing file-based coordination to fix codex deadlock before diagnosing. The cost of pausing is low. The cost of unwinding is high.
