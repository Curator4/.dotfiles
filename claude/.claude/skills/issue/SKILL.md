---
name: issue
description: Show the current ticket's GH parent issue — body, sub-issues hierarchy with progress, comments, link. Use when the user says "show issue", "show the issue", "view issue", "current issue", "tracking issue", "what's tracked", "show subtasks" (read-only view), "/issue", or wants to inspect what's in the active ticket's GH Issue without editing it.
argument-hint: "[ticket-key]"
---

# Issue Skill

Read-only display of the GH parent issue and its sub-issues for the current (or specified) Jira ticket. For editing, use `/subtask`.

## Arguments

- `$0` (optional) — Jira ticket key (e.g. `AR-183`). Defaults to extracting from the current branch.

## Steps

1. **Resolve the ticket key**:
   - If `$0` provided, use that
   - Otherwise extract from current branch (`git branch --show-current`, regex `[A-Z]+-\d+`)
   - If neither works, ask the user

2. **Find the parent issue**:
   - First try open: `gh issue list --search "<KEY> in:title" --state open --json number,title,body,url,comments`
   - If not in open, try closed
   - If neither, tell the user no tracking issue exists — suggest `/start-ticket` or `/to-prd`

3. **Fetch sub-issues** if any:
   - `gh api repos/:owner/:repo/issues/<N>/sub_issues --jq '.[] | {number, title, state, url}'`

4. **Display**:
   - **Header**: `#<N> <title>  [<state>]`
   - **URL**: clickable link
   - **Checklist progress** (parse body for `- [ ]` / `- [x]`): `(X/Y done)`
   - **Sub-issues** (if any): list with state and number, e.g.
     ```
     Sub-issues (2/4 closed):
       #43 [closed] AR-183 phase B: storage layer
       #44 [closed] AR-183 phase B: supervision wiring
       #45 [open]   AR-183 phase B: backpressure
       #46 [open]   AR-183 phase B: tests
     ```
   - **Body**: render the issue body inline
   - **Comment count**: if any, show `<N> comments — fetch with: gh issue view <N> --comments`

## Notes

- Read-only. Use `/subtask` for body/checklist edits, `gh issue close` for closure (handled by `/done`).
- If the user wants comments inline, fetch them with `gh issue view <N> --comments` and display.
- "Sub-issues" are GitHub's first-class child issues (not just `Blocked by #N` references). The progress bar in the parent UI is driven by these.
