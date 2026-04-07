---
name: themis
description: Health tracking and session logging — meals, workouts, weight, summaries, meal reference, and end-of-session diary entries. Use when the user talks about food, exercise, weight, or invokes /themis.
argument-hint: "[optional note or command]"
---

# /themis — Health Tracking & Session Log Skill

## Purpose

Unified health tracking skill. Handles meals, workouts, weight, diary summaries, meal reference lookups, and end-of-session log entries. Dispatches by natural language intent — see the Operation Dispatch section.

## Operation Dispatch

Read the user's message and args, then pick the matching operation:

| User intent | Operation |
|---|---|
| `/themis` or `/themis "did X"` at end of session | Session log |
| "log meal", "ate X", "had X for lunch/dinner/breakfast" | Log meal |
| "log workout", "did chest day", "went for a run", "trained X" | Log workout |
| "log weight", "weighed in at X", "weight is X" | Log weight |
| "what did I eat", "nutrition summary", "calories today/this week" | Nutrition summary |
| "weight trend", "weight this week/month", "how's my weight" | Weight summary |
| "workout summary", "what workouts", "training this week" | Workout summary |
| "recent entries", "diary last N days", "show my log" | Recent entries |
| "add meal reference", "save this meal", "add to meal DB" | Add meal reference |
| "look up meal", "what's in X", "meal macros for X", "find meal" | Get meal reference |

When invoked as `/themis` with no argument or a session note, default to Session log.

---

## Data Paths

- Daily notes: `/home/curator/obsidian-vault/themis/{YYYY}/{YYYY-MM}/{YYYY-MM-DD}.md`
- Meal reference: `/home/curator/obsidian-vault/themis/meals_reference.json`

Always resolve today's date from the system clock before any file operation (`date +%Y-%m-%d`).

---

## Daily Note Template

Create this when a file doesn't exist yet. Use `mkdir -p` via Bash for the month directory first.

```markdown
# entry: {YYYY-MM-DD}

Tags: #themis #{YYYY}
{Weekday} · Week {WW} · [[reference]]

## log

## nutrition

## workout

## stats
```

- `{WW}` = ISO week number (01–53), zero-padded. Get with `date +%V`.
- `{Weekday}` = full weekday name. Get with `date +%A`.

---

## Entry Formats

- **Nutrition:** `- HH:MM | {description} | {calories} kcal | {protein}g protein`
- **Workout:** `- HH:MM | {description}`
- **Weight:** `- {weight}kg` (no trailing zeros: `80` not `80.0`, but `80.5` stays as `80.5`)
- **Session log:** `- ~{duration} — {summary}` (past tense, one sentence)

Get current time with `date +%H:%M` when logging meals or workouts.

---

## Section Insertion Rules

Sections appear in order: `## log`, `## nutrition`, `## workout`, `## stats`.

**Log entries** → append at bottom of `## log`, before `## nutrition`
**Nutrition entries** → append at bottom of `## nutrition`, before `## workout`
**Workout entries** → append at bottom of `## workout`, before `## stats`
**Weight entries** → append at bottom of `## stats` (last section, no next heading)

**Edit patterns:**

If the target section is empty (blank line before the next heading):
- `old_string`: `## {section}\n\n## {next_section}`
- `new_string`: `## {section}\n\n- {entry}\n\n## {next_section}`

If the target section already has entries:
- `old_string`: `\n## {next_section}`
- `new_string`: `\n- {entry}\n\n## {next_section}`

For `## stats` (last section, no next heading):
- If empty: `old_string` = `## stats\n`, `new_string` = `## stats\n\n- {entry}\n`
- If has entries: append after the last line of the file or match the last entry line and add below it.

Use the Edit tool for all insertions. Read the file first to determine which case applies.

---

## Operations

### Session Log

End-of-session diary entry. Triggered by `/themis` or `/themis "note"`.

Steps:
1. Get today's date from system clock.
2. Derive diary path. Create file from template if missing.
3. Read the file.
4. Summarise the session: scan the conversation for the main work done, decisions made, topics explored. 1–2 tight sentences, past tense.
5. Estimate duration from first to last message. Round to nearest 15 min. Format: `Xh`, `Xh Ym`, or `Ym`. Use `?` if unknown.
6. If user provided a note after `/themis "..."`, weave it in or append after `;`.
7. Insert using log insertion rules.
8. Confirm with the entry written. Do not ask clarifying questions — best effort always.

**Duration format:** `~1h 30m`, `~45m`, `~2h`, `~?`

### Log Meal

Steps:
1. Get today's date and current time.
2. Identify: description, calories, protein. If calories or protein are missing, check meal reference DB first (case-insensitive substring match on description).
3. If macros still missing after reference check, ask only if essential (skip asking for protein if user hasn't mentioned it and it's a simple item — use 0).
4. Derive diary path. Create file if missing.
5. Read file to determine section state.
6. Insert into `## nutrition` using nutrition insertion rules.
7. Confirm with entry written.

**Macro auto-fill:** When logging a meal, always check `meals_reference.json` first. If a match is found, use those macros (and tell the user you did).

### Log Workout

Steps:
1. Get today's date and current time.
2. Extract workout description from user message.
3. Derive diary path. Create file if missing.
4. Read file to determine section state.
5. Insert into `## workout` using workout insertion rules.
6. Confirm with entry written.

### Log Weight

Steps:
1. Get today's date.
2. Extract weight value. Normalize: remove trailing `.0` (80.0 → 80), keep decimals otherwise (80.5 stays).
3. Derive diary path. Create file if missing.
4. Read file to determine section state.
5. Insert into `## stats` using stats insertion rules.
6. Confirm with entry written.

### Nutrition Summary

Steps:
1. Determine date range. Default = today. Recognise "this week" (Mon–today), "last 7 days", "yesterday", specific dates.
2. For each date in range, read the daily note if it exists.
3. Parse `## nutrition` entries. Structured entries match `HH:MM | desc | XXX kcal | XXg protein`. Freeform entries count as 0 kcal / 0g protein (note them as untracked).
4. Sum calories and protein per day and overall.
5. Report in prose: totals per day, grand total, flag any untracked entries.

### Weight Summary

Steps:
1. Determine date range. Default = last 7 days. Extend to last 30 if user says "month".
2. For each date in range, read the daily note if it exists.
3. Parse `## stats` entries matching `- XX(.X)kg`.
4. Collect all readings with dates. Calculate: average, min, max, delta (newest − oldest).
5. Report in prose: trend direction, delta, range, average.

### Workout Summary

Steps:
1. Determine date range. Default = last 7 days.
2. For each date in range, read the daily note if it exists.
3. Collect all `## workout` entries with their dates.
4. Report in prose: list workouts by date, total count.

### Recent Entries

Steps:
1. Determine N days. Default = 3. Parse from message ("last 5 days" → 5, "last week" → 7).
2. For each of the last N days, read the daily note if it exists.
3. Report full note contents or a structured summary per day.

### Add Meal Reference

Steps:
1. Extract: name, calories, protein, notes (optional).
2. Read `meals_reference.json`. If file doesn't exist, start with `[]`.
3. Check for existing entry with same name (case-insensitive). If found, update it. If not, append.
4. Write back with 2-space indent.
5. Confirm: "Updated X" or "Added X to meal reference."

### Get Meal Reference

Steps:
1. Extract search term from message. If none, return all meals.
2. Read `meals_reference.json`.
3. Filter: case-insensitive substring match on `name` field.
4. Report in prose: name, calories, protein, notes for each match. Say how many matched.

---

## Confirmation Messages

Keep confirmations short and TTS-friendly. Prose, not tables. Example formats:

- "Logged to themis/2026/2026-04/2026-04-07.md — `- ~1h 15m — Implemented AR-83 poll supervisor.`"
- "Nutrition entry added: chicken and rice, 550 kcal, 45g protein."
- "Weight logged: 82.3kg."
- "Found 2 meals matching 'rice': Brown rice (350 kcal, 7g protein) and Chicken rice bowl (550 kcal, 45g protein)."

---

## Notes

- Do not log Jira worklogs or create tickets. This skill is diary and health only.
- Do not ask clarifying questions for session logging. Always best-effort.
- Always resolve today's date from system clock, not from conversation context.
- Use `mkdir -p` via Bash before creating a new daily note — the month directory may not exist.
- When inserting entries, use the Edit tool. Read the file first to determine empty vs. populated section.
