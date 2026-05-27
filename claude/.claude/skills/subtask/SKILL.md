---
name: subtask
description: Manage the active ticket's GH Issue subtasks — add or tick off checkbox items in the parent issue body, list current state, or promote a checkbox into a real sub-issue when it grows up. Use when the user says "add subtask", "new subtask", "tick off X", "mark X done", "check off X", "show subtasks", "what's left", "promote subtask", "make X a sub-issue", "subtask add", "subtask done", "subtask promote", "/subtask".
argument-hint: "add|done|list|promote [text|index]"
---

# Subtask Skill

Manage subtasks on the parent GH Issue for the current ticket. Two modes:

- **Checklist mode** (default) — checkbox items in the parent issue body. Lightweight, fast.
- **Sub-issue mode** — real GitHub sub-issues, each with its own URL, comments, and PR target. Use for substantive subtasks that warrant their own discussion or PR.

Promote from checklist → sub-issue when a subtask grows up. Don't pre-promote.

## Arguments

- `$0` — action: `add`, `done` (or `check`), `list`, or `promote`
- `$1+` — text content (for `add`) or substring match / index (for `done` and `promote`)

## Steps

### 1. Resolve the active parent issue

- Get the current branch: `git branch --show-current`
- Extract the Jira key with regex `[A-Z]+-\d+` — e.g. `feature/AR-183/storage` → `AR-183`
- If no key found, ask the user which ticket they mean
- Find the matching open GH Issue: `gh issue list --search "<KEY> in:title" --state open --json number,title,body`
- If none found, stop: "No parent issue found for `<KEY>`. Run `/start-ticket` or open one manually (typically via `/to-prd`)."
- If multiple matches, prefer the one whose title starts with the exact key; this is the *parent* issue. Sub-issues should not match the search since they have different titles.

### 2. Dispatch on action

#### `add <text>` — append a checklist item to the parent body

- Read current body: `gh issue view <N> --json body -q .body`
- Locate the checklist section (look for `## Subtasks` or any block of `- [ ]`/`- [x]` lines). If absent, append `## Subtasks` at the end with the new item.
- Add `- [ ] <text>` as the last item.
- Update: `gh issue edit <N> --body "<NEW_BODY>"`
- Confirm: "Added subtask: `<text>` (issue #N)"

#### `done <substring>` — tick off a checklist item

- Read current body
- Find unchecked items (`- [ ] ...`) where the text contains `<substring>` (case-insensitive)
- 0 matches: report which items exist and stop
- Multiple: list and ask which
- 1 match: replace `- [ ]` with `- [x]`
- Update issue body
- Confirm: "Ticked off: `<matched text>` (issue #N — X/Y done)"

#### `list` — show current state

- Read body, extract the checklist section
- Show progress: `(3/5 done)`
- Also list any open sub-issues for this parent (`gh api repos/:owner/:repo/issues/<N>/sub_issues` — filter open)
- Include parent issue number and URL

#### `promote <substring>|<index>` — convert a checklist item into a sub-issue

- Read parent body, find the matching checkbox (by substring or 1-based index in the list)
- Confirm with user: "Promote `<item text>` to a sub-issue of #<parent>? It'll be removed from the checklist and become a separate issue you can close with `Closes #N`."
- If yes:
  - Create the sub-issue with metadata in one shot:
    ```
    gh issue create \
      --title "<item text>" \
      --body "Sub-task of #<parent>." \
      --label "slice" \
      --label "ready-for-agent" \
      --assignee @me
    ```
    (Mark `ready-for-human` instead of `ready-for-agent` if the subtask requires human input.)
  - Set type via REST: `gh api -X PATCH repos/:owner/:repo/issues/<NEW_NUMBER> -f type=Task`
  - Get the new issue's database id: `NEW_ID=$(gh api repos/:owner/:repo/issues/<NEW_NUMBER> --jq .id)`
  - Formalize the parent → child relationship (drives the progress bar in the parent UI):
    ```
    gh api -X POST repos/:owner/:repo/issues/<parent>/sub_issues -F sub_issue_id=$NEW_ID
    ```
  - Remove the checkbox line from the parent body
  - Update the parent body
- Confirm: "Promoted to sub-issue #<new>. Reference it with `Closes #<new>` in your PR when shipping that slice."

### 3. Scope discipline

If the user says `add` for something that sounds *unrelated* to the parent ticket (different feature area, fresh bug discovered), pause and ask: "This sounds like it might be its own ticket rather than a subtask of `<KEY>` — file as Jira backlog via `/create-ticket` instead?" Per WORKFLOW.md, the parent issue stays scoped to one Jira ticket; unrelated work goes to Jira backlog.

If the user confirms it's in scope, add it.

## Notes

- The skill operates on the **parent** issue. Don't accidentally edit a sub-issue's body when the user says "add subtask."
- Sub-issue API: GitHub's REST API `/repos/{owner}/{repo}/issues/{issue_number}/sub_issues` controls the parent-child relationship. `gh issue` doesn't have first-class sub-issue commands as of writing — use `gh api` for the relationship endpoint.
- Don't litter the parent body with comments — those go in `gh issue comment`. Body holds the structured plan + checklist; comments hold prose decisions.
- Promoting a subtask is a one-way action by default. The original checkbox is removed from the parent body. If user changes their mind, re-run `add` to put it back.

## Jira Details

- Cloud ID: `b280f917-9ae0-4c1a-86a8-8c6a2202944b`
- Project: AR
