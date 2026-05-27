---
name: design-ticket-auto
description: Autonomous variant of /design-ticket. Designs a tracker issue without human-in-the-loop — auto-picks the next eligible staging issue (or accepts an explicit number), grills internally against project docs and the code, posts the `## Symphony Workpad`, transitions to `status:todo`. Skips titles prefixed `Brainstorm:` or `Iterate X based on production runs` — those need operator ideation. Use when the user invokes `/design-ticket-auto`, says "autopilot design", "/design-auto", "batch design staging", or wraps this skill in /loop for unattended throughput.
---

# /design-ticket-auto

Non-interactive variant of [`/design-ticket`](../design-ticket/SKILL.md).
Produces the same `## Symphony Workpad` comment structure and the
same `status:staging → status:todo` transition — but every decision
point that `/design-ticket` would prompt the user on is resolved
internally by picking the recommended option and continuing.

This is the right tool when:

- The operator has a backlog of staging issues and wants unattended
  throughput on the design step.
- The operator is wrapping this in `/loop` (typically self-paced)
  for batch design.
- The issue is concrete enough that operator-led grilling wouldn't
  meaningfully change the workpad — e.g. a focused bug with a
  reproducer, or a UX nit with a stated fix.

It is the WRONG tool when:

- The issue is exploratory ("Brainstorm: ...", "Iterate ... based on
  production runs") — these are filed precisely because they need
  the operator's ideation. The auto-pick filter skips them by title.
- The issue body has scope-inversion potential (e.g. the body
  describes one problem but the operator has a different actual
  problem in mind). Auto-design will produce a workpad faithful to
  the body — which may miss what the operator actually wanted.
  These should go through interactive `/design-ticket`.

## Inputs

Either:

- An explicit issue number: `/design-ticket-auto 59`. Designs that
  issue regardless of the eligibility filter — explicit user
  invocation overrides the heuristic.
- No argument: list `status:staging` issues, apply the eligibility
  filter, sort by the picker rule, design the top one.

## Auto-pick heuristic

When no argument is given, pick the next issue this way:

1. Fetch all `status:staging` issues with the `symphony` gate label.
2. **Drop ineligible**:
   - Title matches `^(?i)brainstorm:` — explicit operator signal
     that ideation is needed.
   - Title matches `^(?i)iterate\b` — these tickets are filed to
     refresh based on operator's lived production experience.
   - Body contains a low-signal marker: case-insensitive match on
     any of `TBD`, `to be determined`, `investigate`, `explore`,
     `discuss`, `figure out`, `not sure`. These signal the author
     wanted to think more before acting.
   - Body is shorter than 80 characters — likely a stub.
3. **Sort remaining** by:
   - Priority label asc (`priority/N` labels, lower N = higher
     priority; missing label = lowest priority).
   - Issue number asc (FIFO among same-priority).
4. **Pick the first**. If the filtered list is empty, return cleanly
   without designing anything (the wrapping `/loop` should treat this
   as "drain complete" and stop scheduling next iterations).

Always log the pick decision in the first user-facing line:

```
Picked #59 (Upgrade pill unreadable) — concrete, no priority label,
oldest among eligible. Skipped: #28, #36 (brainstorm:); #39–43
(iterate-based-on-production-runs); #46 (body too short).
```

So the operator can audit what got designed and why others were
deferred.

## Workpad mechanics

Identical to `/design-ticket` — see that skill's
[`Workpad mechanics`](../design-ticket/SKILL.md#workpad-mechanics)
section for the gh CLI commands. One workpad comment per issue;
edits replace in place; archive-then-overwrite the prior workpad if
one exists (reset-to-design case).

## Flow

### 1. Pick

If `<N>` was passed: read `gh issue view <N>` directly. Confirm the
issue is in `status:staging`; if it isn't, return an error so the
caller knows the explicit number was wrong.

If no arg: run the auto-pick heuristic above. Report the pick + the
skip list in one user-facing line.

```bash
gh issue list --state open --label status:staging \
  --json number,title,body,labels,createdAt
```

### 2. Mark session start

Comment on the issue:

```
Design session started by /design-ticket-auto ($(date -Iseconds)) —
autonomous, no human grilling.
```

The "autonomous" tag in the comment is the audit signal: anyone
reading the issue's history knows the workpad below was produced
without an operator-led grilling. If the operator wants to redo
under interactive grilling, they reset the workpad and re-invoke
`/design-ticket`.

### 3. Archive prior workpad if any

Same mechanics as `/design-ticket` step 3 — find the existing
`## Symphony Workpad` comment, rename its header to
`## Symphony Workpad (archived $(date -Iseconds))`, PATCH back. No
human prompt.

### 4. Ground

Read project documentation, in order:

- `AGENTS.md` (or `CLAUDE.md` if no AGENTS.md)
- `.agents/CONTEXT.md` if present
- `ARCHITECTURE.md` if present
- `docs/adr/*.md` if present
- The README's roadmap section

These reads happen autonomously — no prompts, no skips. The grilling
in step 5 leans on this grounding to substitute for operator domain
knowledge.

### 5. Internal grill

Replace `/design-ticket`'s interactive
`superpowers:brainstorming` + `grill-with-docs` invocations with
**internal reasoning**:

- Read the issue body and **identify the load-bearing claims** (the
  problem statement, the proposed fix shape, the acceptance criteria
  if any).
- For each claim, **find the actual code surface** it touches. Grep
  the codebase, read the relevant files. Confirm or contradict the
  claim against the code.
- **Look for scope inversions**: places where the issue body's
  primary fix path would be wrong against the actual code (a
  pattern that has happened in production — see issue #29's
  workpad inversion notes for the canonical example). When found,
  invert the plan and document the inversion in the workpad's
  Notes section as `**Issue-body inversion #N**: <description>`.
- **Look for risks**: edge cases the code reveals that the body
  doesn't mention.
- **Identify out-of-scope items** explicitly. The body may list
  some; the grilling should add more if the code surface suggests
  scope creep is possible.

Write down the analysis in a scratchpad (mental, not on disk) before
producing the workpad. The workpad's Plan, Acceptance Criteria, and
Notes sections all derive from this analysis.

Do NOT invoke `superpowers:brainstorming` or
`superpowers:grill-with-docs` skills — those are interactive and
will block waiting for operator input. The internal reasoning here
is the autonomous substitute.

### 6. Produce the `## Symphony Workpad` comment

Same exact shape as `/design-ticket` step 6 — single comment with
header `## Symphony Workpad`, Plan / Acceptance Criteria /
Validation / Notes / Confusions. See `/design-ticket`'s template
section.

In the Notes section, **always include**:

- `Design session: <date> via /design-ticket-auto (autonomous).`
- The list of issue-body inversions found during grilling, if any.
- An honest **Confidence:** line at the bottom of Notes:
  `Confidence: high/medium/low — <one sentence justification>`.
  High when the body is concrete and grounding confirms it directly;
  medium when there are minor gaps or uncertainties; low when the
  grilling raised more questions than it answered (consider whether
  to skip and surface a `## Auto-design deferred: <reason>` comment
  instead — see "Escapes" below).

Post via `gh issue comment <N> --body-file <path>`.

### 7. Transition to todo

```bash
gh issue edit <N> --add-label status:todo --remove-label status:staging
```

Comment:

```
Workpad ready (auto-designed); transitioning to todo. Symphony will
pick this up on next tick.
```

### 8. Return

Report a single user-facing line summarizing what was done:

```
Designed #59 → status:todo. Workpad: <url>. Confidence: high.
```

If wrapped in `/loop`, this is the line the loop's caller can use
to decide whether to continue. If the auto-pick filter returned
empty, return:

```
No eligible staging issues remain. Stopping.
```

The wrapping `/loop` should treat this as the termination signal.

## Escapes

- **Low-confidence grilling**: If step 5's internal grill produces
  unresolved scope questions that would normally require operator
  input, do NOT post a thin workpad. Instead, post a comment:

  ```
  ## Auto-design deferred: <one-paragraph reason>

  Routed to /design-ticket (interactive) for operator grilling.
  ```

  Leave the issue at `status:staging`. Return a user-facing line:

  ```
  Deferred #N — needs interactive grilling. Continuing.
  ```

  The `/loop` wrapper sees this as a no-op and proceeds to the next
  pick. The operator sees the deferral comment and knows to
  `/design-ticket N` themselves.

- **Issue argued out of scope** (the grilling reveals the issue is
  a duplicate, wontfix, or fundamentally wrong): post a comment
  with the reasoning and close the issue via `gh issue close`.
  Do NOT swallow this silently — the comment is the audit trail.

- **Issue too big** (the grilling reveals it should split): post a
  comment recommending `/to-issues` and leave at `status:staging`
  for the operator. Do not auto-split — `/to-issues` is itself an
  operator-led skill.

## Constraints

- One issue per invocation. Loop externally for batch.
- The skill does NOT implement code during the design session —
  same as `/design-ticket`. Code starts at the implementing stage.
- The `## Symphony Workpad` header must be exact. Different casing
  or spacing breaks symphony's workpad search.
- Never invoke `superpowers:brainstorming` or `grill-with-docs` from
  here — those are interactive and will deadlock the autonomous
  flow.
- Always include the `(autonomous)` marker in the session-start
  comment and the `Design session: ... via /design-ticket-auto
  (autonomous)` line in the workpad's Notes. The audit trail matters.

## Done when

- A `## Symphony Workpad` comment exists on the issue with the
  required structure.
- The issue's label is `status:todo` (success) OR the issue stayed
  at `status:staging` with a `## Auto-design deferred` comment
  (escape — operator will pick it up).
- A single user-facing summary line was emitted so the caller
  (`/loop` or human) knows the outcome.

## Wrapping in /loop

Self-paced is the right shape — designs take variable time. To
batch-process the staging queue:

```
/loop /design-ticket-auto
```

The loop fires `/design-ticket-auto` (no arg → auto-pick), waits
for completion, then fires again. When `/design-ticket-auto`
reports `No eligible staging issues remain. Stopping.`, the loop
terminates.

Run in the **same session** as `/loop` was invoked, since the
loop's cadence is driven by the model's `ScheduleWakeup` calls and
needs the session context to resume. A fresh session is fine as
the starting point (recommended for batch work — clean context),
but don't try to drive the loop from a different session than the
one that invoked it.
