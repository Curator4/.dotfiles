---
name: active
description: "Use when the user asks what they are working on, current ticket status, branch state, recent commits, open PRs, or project context after a break."
---

# Active Skill

Snapshot of in-flight work — branch, ticket, parent issue + sub-issues, commits, PR. Useful when context-switching back after a break.

## Steps

Run these in parallel where independent.

### 1. Branch + ticket key
- `git branch --show-current` → display
- Extract Jira key (regex `[A-Z]+-\d+`). If none, note "branch not tied to a Jira ticket" and skip Jira/issue sections.

### 2. Jira ticket state (if key found)
- Fetch via `getJiraIssue` (Atlassian MCP)
- Display: key, title, status (`In Progress`, `In Review`, ...), assignee

### 3. GH parent issue + sub-issues (if key found)
- `gh issue list --search "<KEY> in:title" --state open --json number,title,body,url`
- If parent found:
  - Show: number, URL, checklist progress (X/Y done from body checkboxes)
  - Fetch sub-issues: `gh api repos/:owner/:repo/issues/<N>/sub_issues`
  - Show sub-issue progress (Y closed / Z total) and a one-line preview of next open sub-issue (or next unchecked checkbox if no sub-issues)
- If parent not found: note "no parent issue (use /start-ticket or /to-prd to create)"

### 4. Recent commits on this branch
- Determine base branch: `git merge-base --fork-point main` (or epic branch if applicable)
- `git log --oneline <BASE>..HEAD | head -10`
- Show as a short list

### 5. Open PR for this branch (if any)
- `gh pr list --head $(git branch --show-current) --json number,state,url,title`
- If exists: `#<N> <title>  [<state>]  <url>`
- If none: that's normal — PRs open at review-ready per WORKFLOW.md

## Output format

Compact, single-screen. Skip empty sections rather than padding with "N/A". Example:

```
Branch:    feature/AR-183/storage
Jira:      AR-183 Storage supervision  [In Progress]
Parent:    #42  https://github.com/...
           Checklist: 3/5 done
           Sub-issues: 1/3 closed
           Next: #45 implement backpressure metrics
Commits:   abc1234 wire up reconnect handler
           def5678 add backpressure metrics
PR:        (none — opens at review-ready)
```

## Jira Details

- Cloud ID: `b280f917-9ae0-4c1a-86a8-8c6a2202944b`
- Project: AR
