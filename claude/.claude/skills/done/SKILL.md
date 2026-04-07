---
name: done
description: "Session Wrap-Up Skill"
---

# Session Wrap-Up Skill

Wrap up the current session.

## Steps

1. Review what was discussed and accomplished in this conversation.
2. Write a 1-2 sentence diary entry to today's Themis daily note:
   - Path: `/home/curator/obsidian-vault/themis/{YYYY}/{YYYY-MM}/{YYYY-MM-DD}.md`
   - If the file doesn't exist, create it using the template from `/themis` skill.
   - Read the file, then use the Edit tool to append to the `## log` section (before `## nutrition`).
   - Format: `- ~{duration} — {summary}` (past tense, one sentence, duration rounded to nearest 15 min).
   - Do NOT touch `## nutrition`, `## workout`, or `## stats`.
3. If any Go code was changed, remind me to update tech docs in `docs/`.
4. Log the session duration as a worklog on the related Jira ticket using `addWorklogToJiraIssue` (e.g. "1h 30m"). Round to the nearest 15 minutes.
5. Check Jira ticket status for any tickets related to this session's work:
   - Always check PR state on GitHub first using `gh pr view <number> --json state,mergedAt` — don't assume based on Jira status alone.
   - If the ticket is **In Review** and the PR was merged on GitHub → transition to **Done** (transition ID `31`).
   - If you're unsure about the state (PR not merged, ticket status unclear, etc.) → ask me before transitioning.
   - Do NOT transition tickets that are still In Progress or where the PR is still open.

## Jira Details

- Cloud ID: `b280f917-9ae0-4c1a-86a8-8c6a2202944b`
- Project: AR
- Extract ticket ID from branch name (e.g. `feature/AR-102/data-parsing` → `AR-102`)

## Diary Entry Style

Include a rough session duration based on the time between the first message and now (e.g. "~2h", "~45min"). Don't stress about precision.

Example: "~1.5h — Worked on SIA DC-09 parser validation — added bounds checking and fixed the CRC edge case. PR #8 ready for review."
