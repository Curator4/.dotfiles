---
name: socratic
description: "Use when toggling Socratic output style on or off via /socratic or /socratic off."
---

# Toggle Socratic output style

Edit `~/.claude/settings.local.json` to flip the `outputStyle` field, then tell the user to `/clear`.

## If the user invoked `/socratic off` (or "default", "disable", "stop")

Run:
```bash
jq 'del(.outputStyle)' ~/.claude/settings.local.json > /tmp/sl.json && mv /tmp/sl.json ~/.claude/settings.local.json
```

Then say: `Socratic off — staged. /clear to apply.`

## Otherwise (turn it on)

Run:
```bash
jq '.outputStyle = "Socratic"' ~/.claude/settings.local.json > /tmp/sl.json && mv /tmp/sl.json ~/.claude/settings.local.json
```

Then say: `Socratic on — staged. /clear to apply.`

## Notes

- Output style is locked into the system prompt at session start for prompt-cache stability — that's why `/clear` is required, not just the toggle.
- Don't elaborate beyond the one-liner. The user knows what they asked for.
