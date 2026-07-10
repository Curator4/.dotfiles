---
name: blindspot
description: "Use when asking what you've missed rather than what could be better — auditing a codebase, design doc, plan, ticket board, host, or toolchain for things that are true but written down nowhere. Invoke on 'blindspot pass', 'what am I not seeing', or before committing to a design."
disable-model-invocation: true
argument-hint: "[target — repo, design doc, host, ticket board, toolchain]"
---

# Blindspot

**A blindspot is something TRUE of the target that is ABSENT from the written record describing it.**

Not "something suboptimal." Suboptimal things are already visible to the person who wrote the system — asking for them samples their own priors back at them. A blindspot is defined by subtraction: `true(artifact) − stated(corpus)`.

## When to invoke

- Before committing to a design, plan, or architecture
- On a system you maintain but haven't examined in a while
- When the user waves something through without engaging
- Never as "find me improvements." That's a different, easier request.

## 1. Resolve the pair

Every run needs an **artifact** (the thing) and a **corpus** (the written record of what's already known about it).

| Target | Artifact | Corpus |
|---|---|---|
| Codebase architecture | code, module graph, schema | `ARCHITECTURE.md`, `adr/`, `CONTEXT.md` |
| A design or plan | the doc | ADRs, prior designs, ticket history |
| Work organization | tickets, labels, states, staleness | `WORKFLOW.md`, ticket bodies |
| System / host | live host — units, journal, disk, packages | `HOST.md`, `KNOWN-ISSUES.md`, `TOOLS.md` |
| Toolchain | installed tools, dotfiles, configs | dotfile comments, `CLAUDE.md`, changelogs |

Read the corpus **fully** before looking at the artifact. It's the subtrahend; you cannot subtract what you haven't read.

**Guard:** if the corpus is thin or absent, stop and say so. A blindspot pass on an undocumented system degenerates into an ordinary code review, and will produce a pile of obvious things dressed as insight.

## 2. Choose lenses

Pick 3–5 from [LENSES.md](LENSES.md), matched to the target. A lens is a **person who has personally been burned by one class of failure** — not a topic. "Security" is a topic. "Someone who has watched a credential leak through a log line" is a lens.

Run them **independently and blind to each other.** Lenses that see each other's output converge on the same safe answer, which is the failure this whole skill exists to avoid.

Each lens returns at most **two** candidates. A lens with nothing to say returns nothing — that is a valid and useful result.

## 3. Classify every candidate

| Class | Claim shape | Verified by |
|---|---|---|
| **Internal** | true of *your* system, never written down | reading the system — cite file:line, unit, key |
| **External** | true of *the world*, never absorbed here | `WebSearch` for the authority, **then pin it** |

**The pin is not optional.** An external finding must name the exact file, line, config key, or unit on this system that the world's knowledge lands on. Unpinned external findings are dropped without discussion.

This is the failure mode that kills blindspot passes. The danger is not that a finding is *false* — websearch makes findings correct. The danger is **true but not about you**: authoritative, well-sourced, generic best practice with no purchase on this system. It reads exactly like insight. Drop it.

Every candidate carries: the claim (one falsifiable sentence), the pin, a concrete failure scenario (inputs → wrong outcome), and the **corpus check** — which corpus file would have mentioned this, and confirmation that it doesn't.

## 4. Subtract

Drop any candidate whose claim is already stated in the corpus. Drop any candidate present in the dismissal log (`~/.claude/blindspot-dismissed.json`, keyed by `scope` + `topic`). This step is mechanical — grep, don't deliberate.

## 5. Refute

For each survivor, run independent skeptics prompted to **refute, defaulting to refuted when uncertain**. Majority refutation kills the finding. Give skeptics distinct angles when a finding could fail in more than one way (is the claim true / is the pin right / does the scenario actually reproduce).

Survivors are what you report. If nothing survives, report that. **A clean pass is a real result** — do not backfill.

## 6. Deliver as a decision surface

Emit an HTML artifact. A blindspot list is not a document, it's a set of decisions: each finding gets **Act**, **Dismiss**, or **Defer**.

Resolve every finding in the session that produced it:

- **Act** — do it now, or open a ticket with a named owner and date.
- **Dismiss** — append to the dismissal log *with the reason*. Never re-raise.
- **Defer** — allowed, but carries an expiry. A lapsed deferral becomes a dismissal.

## Constraints

- **Never park a finding in a backlog.** A backlog is where findings go to not be decided.
- **No count targets.** "Find five things" manufactures four.
- **The lens must be someone you are not.** If the finding is one the author would have reached alone, it isn't a blindspot — it's a code review.
- Blindspot findings have worse precision than improvement findings. That is the price of the quadrant, not a defect. The dismissal log is the correction channel; it only works if it is actually written.

## Scaling

Small target — parallel `Agent` calls, one per lens, then a refute pass.

Large target, or the user said `ultracode` — a `Workflow`: pipeline lenses into per-finding refutation so each finding verifies as soon as its lens lands, then a completeness critic asking what modality was never run.
