#!/usr/bin/env bash
# PreToolUse hook for Bash. Reminds Claude to run /pr and /done pipelines
# before pushing or creating a PR. Non-blocking — injects additional context
# via JSON output so the user doesn't see noise on intentional pushes.

set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

if [[ -z "$cmd" ]]; then
    exit 0
fi

if printf '%s' "$cmd" | grep -qE '(^|&&[[:space:]]*|\|\|[[:space:]]*|;[[:space:]]*|\|[[:space:]]*)(git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+create)([[:space:]]|$)'; then
    jq -nc '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: "Reminder: this looks like the end of a ticket. Did you run /pr (six-lens review) and /done (wrap-up + diary + docs-update)? If this push is mid-work or a force-update on an existing PR, ignore."
      }
    }'
fi

exit 0
