---
name: start-ticket
description: Start working on a Jira ticket — creates branch, sets upstream, transitions ticket to In Progress, and explores the codebase with ticket context. Use when the user says "start ticket", "pick up ticket", "work on AR-xxx", etc.
argument-hint: "<ticket-id> <branch-slug> [base-branch]"
---

# Start Ticket

Pick up a Jira ticket and get ready to work.

Usage: `/start-ticket AR-103 response-generation` or `/start-ticket AR-103 response-generation epic/notifications`

## Arguments

- `$0` — Jira ticket ID (e.g. `AR-103`)
- `$1` — Branch slug (e.g. `response-generation`)
- `$2` — Base branch to branch off (optional, defaults to `main` — use for epic branches)

## Steps

1. **Fetch ticket context** from Jira using `getJiraIssue` with the ticket ID
2. **Create and push branch**:
   - Branch name: `feature/$0/$1` (e.g. `feature/AR-103/response-generation`)
   - Base: `$2` if provided, otherwise `main`
   - Make sure base is up to date (`git pull` on it first)
   - Create the branch, push, and set upstream (`git push -u origin <branch>`)
3. **Transition ticket to In Progress** — use `transitionJiraIssue`. Get available transitions first to find the right ID.
4. **Show a brief ticket summary** — title, description, acceptance criteria if present. Keep it short. Add a note that the specs are AI-generated so take them as rough intent, not gospel.
5. **Explore the codebase** with the ticket context in mind:
   - Identify which files/packages are relevant to the ticket's intent
   - Note existing patterns that the implementation should follow
   - Flag anything that might be tricky or worth discussing
   - Present a short summary of findings and a suggested approach
   - Don't blindly follow the ticket spec — understand the *intent* and map it to what actually exists in the codebase

## Jira Details

- Cloud ID: `b280f917-9ae0-4c1a-86a8-8c6a2202944b`
- Project: AR
