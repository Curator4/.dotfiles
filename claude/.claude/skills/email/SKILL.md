---
name: email
description: "Use when the user asks about email, inboxes, message triage, summaries, or email actions."
argument-hint: "[optional: role filter or natural language like 'check work email']"
---

# Email Skill

Fetch and triage emails using the `email-tool` CLI and a haiku subagent for classification.

**Critical: protect main context.** Raw email output must NEVER land in the main conversation. All fetching and classification happens inside a subagent. Only the short digest comes back.

## Flow

### Step 1: Determine scope

Parse user input for filters:
- "work email" / "personal" → use `--role work` or `--role personal`
- Specific account name → use `--account NAME`
- "from yesterday" / "last 3 days" → use `--since YYYY-MM-DD`
- "all emails" / "include read" / "everything" → use `--all` (default is unread only)
- No qualifier → fetch all accounts, unread only

Build the fetch command string: `email-tool fetch [--role ROLE] [--account NAME] [--since DATE]`

### Step 2: Fetch + Classify (single subagent)

Spawn ONE haiku subagent that does BOTH the fetch and classification. The subagent runs `email-tool fetch` via Bash inside its own context, classifies the output, and returns only the digest.

```
Agent(
  model: "haiku",
  description: "Fetch and classify emails",
  prompt: """
    You are an email triage assistant.

    Step 1: Run this command via Bash:
    email-tool fetch {flags}

    Step 2: Classify the output.

    Output format — a concise digest grouped by account:

    For IMPORTANT emails (direct messages from real people, billing, alerts):
    - One sentence summary of what it says and if action is needed

    For NOISE (newsletters, notifications, marketing, automated):
    - Just list them as one line: "3x LinkedIn notifications, 2x GitHub notifications"

    Keep it brief and scannable.
    If an account has errors, note it briefly (e.g. "magic: auth failed").
    If no new messages anywhere, just say "Inbox is clear."

    Account roles: work accounts are for professional context, personal for everything else.

    IMPORTANT: After the human-readable digest, append a machine-readable block like this:

    [EMAIL_DATA]
    account:uid:category — short label
    account:uid:category — short label
    [/EMAIL_DATA]

    Categories: important, noise
    Example: curator4:1234:noise — Crunchyroll notification

    This block is required even if all emails are noise. It enables actions without re-fetching.

    Your final message must be ONLY the digest text followed by the EMAIL_DATA block. Nothing else.
  """
)
```

### Step 3: Present and wait

Show the subagent's digest to the user. The digest is compact — UIDs are preserved for actions.

### Step 4: Act (no subagent needed)

If the user says things like "delete the spam", "archive the LinkedIn stuff", "mark the Jira ones as read":

1. Parse the `[EMAIL_DATA]` block from the digest to get account:uid pairs
2. Match the user's instruction to the relevant entries (e.g. "clean it out" = delete all noise, "delete the LinkedIn stuff" = delete entries with LinkedIn in the label)
3. Build the action JSON directly: `[{"account": "name", "uid": "123", "action": "delete|archive|mark-read"}]`
4. Run via Bash: `echo '<the JSON>' | email-tool act`
5. Report what was done in one sentence.

No re-fetch needed. No second subagent. The UIDs are already in the digest.
