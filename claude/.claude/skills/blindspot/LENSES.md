# Lenses

A lens is **a person who has personally been burned by one class of failure.** Not a topic, not a checklist, not a job title.

The test: could the author of the artifact have produced this finding alone? If yes, it isn't a lens — it's a mirror.

```
✗ "Review this for security."           → topic. Returns OWASP.
✗ "You are a senior engineer."          → title. Returns taste.
✓ "You once shipped a fix that logged   → lens. Returns the log line
   a bearer token into journald and        on line 212.
   found it a year later in a backup."
```

Write the burn in the first person and make it specific enough to hurt. The specificity is what moves the lens off the author's own map.

## Codebase & architecture

- Watched a nil map write take down a service at peak, and now reads every struct field for who initializes it.
- Debugged a deadlock caused by a lock held across a channel send, and reads every `defer mu.Unlock()` for what happens in between.
- Inherited a codebase where every error was `fmt.Errorf("%v")`, and lost three days to an error that could not be `errors.Is`'d.
- Has seen a "temporary" adapter package outlive three rewrites.
- Once removed a mutex that was load-bearing for a reason nobody had written down.

## Data & persistence

- Lost data to a missing unique index that everyone assumed the application layer enforced.
- Has been on the wrong side of a migration that was reversible in staging and not in production.
- Watched a `SELECT` without `FOR UPDATE` double-process a queue under concurrency.
- Has seen a schema where the invariant lived only in the mind of the person who left.

## Systems & operations

- Was paged at 3am for a disk that filled with logs nobody read.
- Has restored from a backup that had been silently failing for eight months.
- Watched a cron fail silently because it wrote to a file instead of exiting nonzero.
- Has seen a service survive every restart test and die on the first cold boot.
- Knows what a `sleep 10` in a unit file is standing in for, and what it costs.

## Work organization

- Has watched a backlog become a graveyard, and can tell a deferred item from a dead one by its shape.
- Has seen the same bug filed four times under three vocabularies.
- Knows that a ticket which nobody can name the owner of will not be done.
- Has seen a label taxonomy that describes the team of two years ago.

## Toolchain & dependencies

- Was bitten by a default that changed in a minor version and was documented only in a changelog.
- Has maintained a config that silently stopped being read after an upgrade.
- Knows which "deprecated" warnings are real deadlines and which are decoration.

## Designs & plans

- Has seen a design whose failure mode was never described, only its success path.
- Knows the difference between a decision that was made and one that was defaulted into.
- Has watched a plan survive contact with reality by quietly changing what "done" meant.
- Reads every "we can always change it later" for what would actually have to be touched.

## Writing a new lens

1. Name the failure class, not the domain.
2. Attach a scar: a specific incident, in first person, with a detail that could only come from having been there.
3. Ask what that person notices *before they read the code* — that's the lens's angle of attack.
4. Confirm the author of the artifact does not already have this scar. If they do, it produces quadrant-one findings and you've wasted a slot.

## Anti-patterns

- **Lens soup.** Five lenses that are all "experienced engineer" with different nouns. They will converge.
- **The completeness lens.** "Check everything." Produces a survey, not a finding.
- **Lenses that can see each other.** Independence is the mechanism. Fan out blind.
- **Borrowing the author's scars.** The scar has to be one the author doesn't have, or the finding was already on their map.
