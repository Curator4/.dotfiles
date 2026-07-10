---
name: start-ticket
description: "Use when starting or picking up a Jira ticket, creating the branch, moving status, or fetching linked GH issue context."
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

1. **Fetch ticket context** from Jira using `getJiraIssue` with the ticket ID.

2. **Locate the matching GH Issue** (per WORKFLOW.md, every active Jira ticket has a 1:1 parent GH Issue holding the substantive content):
   - `gh issue list --search "<KEY> in:title" --state all --json number,title,state,body`
   - **If found and open**: this is the parent issue. Show its title and a 2-3 line summary of what's there (PRD content, sub-issues, checklist, etc.). Note the issue number for later commit/PR references.
   - **If found but closed**: unusual — confirm with the user whether they're reopening work. Don't proceed silently.
   - **If not found**: stop and tell the user. The ticket needs a parent GH Issue first. Suggest the right authoring path:
     - "If this is a vague Jira ticket from the backlog (the common case): `/triage` will create the parent GH Issue from the Jira context, classify it through the state machine (bug/enhancement + needs-triage/needs-info/ready-for-agent/ready-for-human/wontfix), grill via `/grill-with-docs` if the description is too thin, and write an agent brief comment when ready. Usually the right path for vague tickets."
     - "If this is a fresh feature being designed in this session: `/grill-with-docs` to align, then `/to-prd` to write the PRD as the parent issue, then `/to-issues` to break into tracer-bullet sub-issues."
     - "If this is a refactor: `/improve-codebase-architecture` will explore and write the RFC issue directly."
     - "If this is small enough that a checklist suffices: open a parent issue manually with the Jira key in the title, body containing a brief plan + checklist."
   - Don't auto-create a bare placeholder issue — that defeats the purpose of the parent issue holding substance.

3. **Create and push branch**:
   - Branch name: `feature/$0/$1` (e.g. `feature/AR-103/response-generation`)
   - Base: `$2` if provided, otherwise `main`
   - Make sure base is up to date (`git pull` on it first)
   - Create the branch, push, and set upstream (`git push -u origin <branch>`)

4. **Transition Jira ticket to In Progress** — use `transitionJiraIssue`. Get available transitions first to find the right ID.

5. **Show a brief synthesis** combining Jira ticket context and the GH parent issue:
   - Jira: title, status, acceptance criteria if present.
   - GH Issue: number, body summary, sub-issue list (if any) with which are still open.
   - Note that Jira is the management view (rough specs, often AI-generated) and the GH Issue holds the substantive plan.

6. **Explore the codebase** with ticket + issue context in mind:
   - Identify which files/packages are relevant
   - Note existing patterns the implementation should follow
   - Flag anything tricky or worth discussing
   - Present a short summary of findings and a suggested approach
   - Don't blindly follow the spec — understand the *intent* (from both Jira and the GH Issue) and map it to what actually exists

## Jira Details

- Cloud ID: `b280f917-9ae0-4c1a-86a8-8c6a2202944b`
- Project: AR

## GH Issues

Per WORKFLOW.md: every active Jira ticket has a 1:1 parent GH Issue. The parent holds the substantive content (PRD, plan, breakdown). Sub-issues handle tracer-bullet vertical slices when warranted. This skill verifies the parent exists before starting work — it does NOT create one, because creating an empty parent defeats the purpose.
