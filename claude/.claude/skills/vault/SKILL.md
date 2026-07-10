---
name: vault
description: "Use when searching the Obsidian vault for notes, docs, journal entries, project context, or remembered content."
argument-hint: "<search query>"
---

Search the user's Obsidian vault at `/home/curator/obsidian-vault/` for the given query.

## Vault Structure

```
dev/          — Technical knowledge base (Docker, Go, SQL, networking)
themis/       — Personal journal/daily logs (YYYY/YYYY-MM/YYYY-MM-DD.md)
vidya/        — Gaming content (campaign reports, strategy)
Learning/     — Educational materials (Deep Learning)
nutrition/    — Nutrition tracking + meal reference
exercise/     — Workout routines
PNC Work/     — Work-related notes
Literature/   — Books & authors
Root level    — Mixed notes, todos, personal content
```

Common tags: `#journal`, `#dev`, `#themis`, `#learning`, `#go`, `#docker`, `#nutrition`, `#work`, `#database`

## Search Strategy

1. Extract keywords from the user's query.
2. If the intent is clearly scoped to a topic area, search that subdirectory first:
   - "docker notes" → search `dev/` first
   - "journal" or "diary" → search `themis/`
   - "workout" or "exercise" → search `exercise/`
   - "nutrition" or "meal" → search `nutrition/`
   - "work" → search `PNC Work/`
3. Use the Grep tool to search file contents. Always exclude `.obsidian/`, `.stfolder/`, and `.git/`.
4. For tag searches, grep for the literal `#tagname` pattern.
5. For date-scoped journal searches, narrow the path to `themis/YYYY/YYYY-MM/`.
6. Use Glob for filename pattern matching when the query suggests a specific file title.
7. If the content grep yields too many results, refine with a more specific term.
8. Read matched files to extract the relevant snippet — do not dump entire files.

## Output Rules

- Cap results at 10 matches.
- Show the file path relative to the vault root, plus 1-2 lines of context around the match.
- Keep output concise — snippets, not full files.
- If one file is clearly the best match, offer to read it in full.
- When multiple files match, briefly summarize what each one contains — don't just list paths.
- Summarize findings in prose so the output reads naturally when spoken aloud.
- If nothing is found with the first search, try alternate keywords before giving up.

## Grep Exclusions

Always pass these glob exclusions (or search a specific subdirectory):
- Exclude `.obsidian/`
- Exclude `.stfolder/`
- Exclude `.git/`

When using the Grep tool, set `path` to `/home/curator/obsidian-vault/` (or a subdirectory) and use the `glob` parameter to restrict file types to `**/*.md` to avoid binary hits.
