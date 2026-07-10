---
name: design-ticket
description: "Use when designing or grilling a tracker issue before implementation, especially /design-ticket, staging issues, or Symphony workpad creation."
---

# /design-ticket

Interactive design stage for a GitHub issue. Bridges the gap between
"someone filed a ticket" and "symphony picks it up to implement" — the
human-in-the-loop design phase.

This skill produces a `## Symphony Workpad` comment in the structure
the symphony pipeline (M6) expects. The implementing stage reads it as
the contract.

## When to use

- After triaging an issue into `status:staging` and you're ready to
  think it through.
- Before any non-trivial symphony run. The implementing stage requires
  a `## Symphony Workpad` comment as input; this skill produces it.
- When you want to grill an architecture decision against existing
  project docs (AGENTS.md / AGENTS.md / CONTEXT.md / ADRs) before any
  code is written.

## Inputs

Either:

- An explicit issue number: `/design-ticket 42`
- No argument: list all `status:staging` issues, prompt to pick one.

The repo is inferred from the current working directory's git remote.
If multiple repos in scope, ask.

For reset-to-design from human review, the operator first relabels
`human-review → staging` (`gh issue edit <N> --add-label
status:staging --remove-label status:human-review`) and then runs
this skill, which sees the issue at `status:staging` like any other
new design — but with a prior workpad to archive in step 3.

## Workpad mechanics

The workpad is a **single** GitHub issue comment with header
`## Symphony Workpad`. Edits replace that comment in place — do not
post a new one for updates. Archiving (used in step 3 below) renames
the header so symphony's implementing/reviewing stages skip it.

```bash
# Find the workpad comment ID (if any):
WORKPAD_ID=$(gh issue view <N> --json comments \
  --jq '.comments[] | select(.body | startswith("## Symphony Workpad")) | .id' \
  | head -1)

# Read the current body to a temp file you can edit:
gh api repos/<owner/repo>/issues/comments/$WORKPAD_ID --jq '.body' \
  > /tmp/workpad-current.md

# After editing /tmp/workpad-current.md, write it back:
gh api -X PATCH repos/<owner/repo>/issues/comments/$WORKPAD_ID \
  --field body=@/tmp/workpad-current.md
```

To post a brand-new workpad comment (used in step 6 below):

```bash
gh issue comment <N> --body-file /tmp/workpad-new.md
```

**`gh issue comment --body @<path>` does NOT read from a file.** The
`--body` flag takes a literal string, so the body posts as the verbatim
characters `@/tmp/...`. Use `--body-file <path>` for `gh issue comment`,
and `--field body=@<path>` for `gh api -X PATCH`.

## Flow

### 1. Pick

```bash
gh issue list --state open --label status:staging --json number,title
```

If `<N>` was passed as arg, look it up and confirm; otherwise show
the list and ask which one. Read the picked issue's full body via
`gh issue view <N> --json body,title,labels,comments`. The comments
fetch is load-bearing: a reset-to-design issue has a prior workpad
on it that step 3 will archive and the grilling will reference.

### 2. Mark session start

Comment on the issue: `Design session started by /design-ticket
($(date -Iseconds))`. This is the audit trail signal — the issue
stays at `status:staging` throughout grilling. No label swap.

### 3. Archive prior workpad if any

If a `## Symphony Workpad` comment already exists on the issue (a
reset-to-design from human review, or a prior interrupted design
pass), rename its header so the implementing stage's comment-search
skips it. Soft-archive instead of hard-delete — the audit trail
matters, and the operator may want to reference the prior plan
during the new grilling.

Per the **Workpad mechanics** section above: fetch the body, replace
the first line, PATCH back.

```bash
WORKPAD_ID=$(gh issue view <N> --json comments \
  --jq '.comments[] | select(.body | startswith("## Symphony Workpad
")) | .id' \
  | head -1)

if [ -n "$WORKPAD_ID" ]; then
  gh api repos/<owner/repo>/issues/comments/$WORKPAD_ID --jq '.body' \
    > /tmp/workpad-prior.md
  # Replace the first line "## Symphony Workpad" with
  #   "## Symphony Workpad (archived $(date -Iseconds))"
  # in /tmp/workpad-prior.md, then PATCH back:
  gh api -X PATCH repos/<owner/repo>/issues/comments/$WORKPAD_ID \
    --field body=@/tmp/workpad-prior.md
fi
```

The implementing stage's workpad-search matches an exact
`## Symphony Workpad` header (no parens) and skips archived ones,
so renaming is sufficient. No prior workpad → no-op.

### 4. Ground

Read the project's design documentation, in this order:

- `AGENTS.md` (or `AGENTS.md` if no AGENTS.md)
- `.agents/CONTEXT.md` if present (project domain glossary)
- `ARCHITECTURE.md` if present
- `docs/adr/*.md` if present
- The README's roadmap section for context on adjacent work

Do not skim — the grilling depends on the agent actually holding
the project's domain language.

### 5. Brainstorm + grill

Invoke the `superpowers:brainstorming` skill if the issue scope is
genuinely ambiguous (e.g. "improve performance of X" — what does X
look like, what's the bottleneck, what's "improved"). Skip if the
issue body is already concrete.

Then invoke `grill-with-docs` (the heavier grilling that challenges
the plan against documented domain decisions and updates docs
inline as decisions crystallise). The session is interactive: agent
challenges, user responds, agent challenges back. Continue until
the user is satisfied that the architecture is right.

The user has full control over depth. They can short-circuit at any
time with "good enough, write the workpad."

### 6. Produce the `## Symphony Workpad` comment

When the user is ready, post a single comment with this exact
structure (the template the implementing stage parses):

````markdown
## Symphony Workpad

```text
<hostname>:<abs-workdir>@<short-sha>
```

### Plan

- [ ] 1\. <parent task name> — <one-line scope>
  - [ ] 1.1 <child task>
- [ ] 2\. <parent task name>
- [ ] 3\. ...

### Acceptance Criteria

- [ ] <testable criterion derived from the grilling>
- [ ] <testable criterion>
- [ ] <testable criterion>

### Validation

- [ ] targeted tests: `<command(s) the implementer should run>`
- [ ] build clean: `<build command>`
- [ ] lint clean: `<lint command>`

### Notes

- Design session: <date> via /design-ticket.
- Design summary: <2-3 sentences capturing the agreed approach>.
- Out of scope (deliberate): <things that came up but we agreed
  weren't this issue>.
- Risks / open questions: <things the implementer should know>.

### Confusions

- (intentionally empty at design time; the implementer will fill
  this if they hit something unclear)
````

The implementing stage reads this workpad as the contract:
- Plan items are sequential subtasks the implementer works through.
- Acceptance Criteria are the test contract.
- Validation lists the commands the verify gate runs.
- Notes captures shared context.

The environment-stamp code-fence at the top is updated by the
implementing stage on each entry; you can leave it as a placeholder
or just fill in the design-time values (the implementer will
overwrite).

### 7. Transition to todo

```bash
gh issue edit <N> --add-label status:todo --remove-label status:staging
```

Comment: `Workpad ready; transitioning to todo. Symphony will pick
this up on next tick.`

End the skill. The user can now leave it to symphony, or watch the
dashboard at `http://127.0.0.1:8090/`.

Symphony's implementing stage will immediately self-transition the
label from `status:todo` to `status:implementing` on entry, per the
M6 spec.

## Escapes

- **User wants to abandon during grilling.** Transition the label
  back to `status:staging` (so it's still in the inbox) and post a
  `## Design abandoned: <reason>` comment. Do NOT post the workpad.
- **The grilling reveals the issue is wrong** (duplicate, out of
  scope). Close the issue with `gh issue close --comment "<reason>"`
  after the user confirms.
- **The grilling reveals the issue is too big.** Use the
  `/to-issues` skill to break it into smaller issues; close the
  original with a link to the children.

## Constraints

- One issue per invocation.
- The agent does not implement code during this skill. Code starts
  in the implementing stage. If the user is tempted to "just sketch
  it quickly" — stop. The workpad is the deliverable.
- The `## Symphony Workpad` comment is **the** workpad. Do not
  create a second one — the implementing stage and reviewing stage
  both look for the marker and skip duplicates by ID. If the user
  wants to revise, edit the existing comment in place; do not post
  a new one.
- **Include the literal `## Symphony Workpad` header**, exactly.
  Different casing or spacing breaks the implementing stage's
  search.

## Done when

- A `## Symphony Workpad` comment is on the issue with the
  structure above.
- The issue's label is `status:todo`.
- The user has explicitly said the design is good (no auto-promote
  without confirmation).
