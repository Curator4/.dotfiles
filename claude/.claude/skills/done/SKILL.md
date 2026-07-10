---
name: done
description: "Use when wrapping up a work session, recording a Themis diary entry, updating docs, checking status, or running the ticket closeout flow."
---

# Session Wrap-Up Skill

Wrap up the current session.

## Flags

- `--skip-docs` — skip the post-merge docs-update dispatch (step 7). Otherwise it fires by default whenever the PR was merged in this session.

## Steps

1. Review what was discussed and accomplished in this conversation.

2. Write a 1-2 sentence diary entry to today's Themis daily note:
   - Path: `/home/curator/obsidian-vault/themis/{YYYY}/{YYYY-MM}/{YYYY-MM-DD}.md`
   - If the file doesn't exist, create it using the template from `/themis` skill.
   - Read the file, then use the Edit tool to append to the `## log` section (before `## nutrition`).
   - Format: `- ~{duration} — {summary}` (past tense, one sentence, duration rounded to nearest 15 min).
   - Do NOT touch `## nutrition`, `## workout`, or `## stats`.

3. **Pre-merge docs check** (only matters if the PR is still open). If any Go code in this branch needs immediate doc reflection in the PR — e.g. a reviewer should see updated docs alongside the code — do it now or flag as a PR blocker. Otherwise skip; post-merge auto-dispatch in step 7 handles docs sync after the PR lands.

4. Log the session duration as a worklog on the related Jira ticket using `addWorklogToJiraIssue` (e.g. "1h 30m"). Round to the nearest 15 minutes.

5. Check Jira ticket status for any tickets related to this session's work:
   - Always check PR state on GitHub first using `gh pr view <number> --json state,mergedAt,baseRefName` — don't assume based on Jira status alone.
   - If the ticket is **In Review** and the PR was merged on GitHub → transition to **Done** (transition ID `31`). This applies even when the PR merged into a long-lived refactor branch rather than `main` — the phase merge is the deliverable's terminal event for that ticket; the umbrella-into-main is a separate later event.
   - If you're unsure about the state (PR not merged, ticket status unclear, etc.) → ask before transitioning.
   - Do NOT transition tickets that are still In Progress or where the PR is still open.

6. **Verify the GH Issue hierarchy closed correctly** (per WORKFLOW.md):
   - Find the parent issue: `gh issue list --search "<KEY> in:title" --state all --json number,state`
   - **If the PR's `baseRefName` is the repo's default branch**, `Closes #N` auto-fires. Verify with `gh issue view <N> --json state`.
   - **If the PR's `baseRefName` is a non-default branch** (e.g. an epic or long-lived refactor branch), GitHub does NOT auto-close on merge — `Closes #N` only fires for default-branch merges. Manually close the parent: `gh issue close <N> --comment "Closed on <PHASE> umbrella merge into <baseRefName> (PR #<num>). The <baseRefName> → main merge is its own terminal event later."`
   - If the parent has sub-issues, list them: `gh api repos/:owner/:repo/issues/<N>/sub_issues --jq '.[] | {number, title, state}'`
   - If the parent is closed but any sub-issues are still open, that's likely a problem — flag and ask. Either close them manually if they shipped (`gh issue close <M>`), or reopen the parent if work isn't actually done.
   - If the PR closed only a sub-issue and the parent should stay open, that's normal — confirm parent has remaining sub-issues open.

7. **Dispatch /docs-update for the merged ticket** (default-on; skip if `--skip-docs` was passed to /done):
   - Skip entirely if the PR was not merged this session (docs catch up post-merge, not pre-merge — step 5's `gh pr view` has the state).
   - Skip if `--skip-docs` was on the /done invocation.
   - Determine the commit range (must run BEFORE step 8 cleanup so the feature-branch ref still resolves locally):
     - PR-merged ticket on a feature branch: `<baseRefName>..<feature-branch>` — gives the agent the original commit-by-commit context, before squash.
     - Long-lived refactor branch with direct commits and no PR: range is the commits this ticket added. Use the previous ticket-close commit as the base if identifiable from `git log --oneline | grep <ticket-prefix>`; otherwise `HEAD~N..HEAD` for a recent stretch and let the agent self-no-op on irrelevant commits.
   - Determine the ticket key from the branch name (same regex as Jira).
   - Optionally compose a 2–3 sentence intent note in shape-of-system terms (what the ticket actually changed in code, not what it tracked). Skip if the diff is self-evident.
   - Optionally identify obvious cross-cutting pages affected (`src/architecture.md`, `src/shutdown.md`, `src/routing.md`, `src/forwarding.md` umbrella).
   - Invoke the wrapper:
     ```bash
     ~/.agents/skills/docs-update/wrapper.sh \
       --range="$RANGE" \
       --ticket="$TICKET" \
       --intent="$INTENT" \
       --crosscutting="$CROSSCUTTING"
     ```
   - The wrapper returns immediately. Do not wait — mako will notify on completion.
   - Report dispatch to the user: `📚 dispatched docs-update for $TICKET (range $RANGE)`. Continue to step 8.
   - The spawned agent self-no-ops on irrelevant diffs, so dispatching for tickets that don't change docs is cheap (~10 seconds, no commit, quiet success notification). Do not gate on "did this ticket touch docs?" — let the agent decide.

8. Clean up the merged feature branch:
   - Confirm the PR was merged AND the remote branch was deleted (`git ls-remote --heads origin <branch>` returns empty). If the remote still exists, stop and ask — don't delete a local branch whose remote is still live.
   - Determine the correct landing branch: the PR's `baseRefName` (`gh pr view <number> --json baseRefName`) — usually `main`, sometimes an `epic/*` branch.
   - `git checkout <baseRefName> && git pull --ff-only` to sync the local landing branch.
   - `git branch -D <feature-branch>` to delete the local feature branch (use `-D` since squash-merges aren't recognized as merged by `-d`).
   - Skip if there's no feature branch to clean up (e.g. session was on main, or branch was already deleted).

## Jira Details

- Cloud ID: `b280f917-9ae0-4c1a-86a8-8c6a2202944b`
- Project: AR
- Extract ticket ID from branch name (e.g. `feature/AR-102/data-parsing` → `AR-102`)

## Diary Entry Style

Include a rough session duration based on the time between the first message and now (e.g. "~2h", "~45min"). Don't stress about precision.

Example: "~1.5h — Worked on SIA DC-09 parser validation — added bounds checking and fixed the CRC edge case. PR #8 ready for review."
