# Io Briefing Agent Memory

## ⚠️ CRITICAL: Output Order Bug
The #1 failure mode is writing `briefing-context.md` as the LAST action, which causes the file write confirmation to be returned instead of the briefing. ALWAYS write context BEFORE composing the final briefing output. If the write hangs or fails, skip it — delivering the briefing is more important than saving context.

Also: if any file read (memory, backlog, etc.) hangs or fails, skip it and proceed with what you have. Never let a stuck tool call block the entire briefing.

## Jira Access
- Cloud ID: b280f917-9ae0-4c1a-86a8-8c6a2202944b
- User email: curator@pnc.dk
- Jira can rate-limit — if it 429s, skip that section gracefully

## User Context
- Based in Fredensborg, Denmark (hardcoded in agent definition, don't add to spawn prompt)
- Has a brother nearby — gym buddy commitment for Sundays
- Dad is also boss at PNC — work accountability has personal dimension
- GP appointment Feb 23 for ADHD referral + sertraline + bloodwork
- Uses Epiduo (acne medication) — causes face/eye irritation

## Nutrition Targets (set Feb 26)
- **Goal**: Cut — visible abs
- **Daily calories**: 1800 kcal
- **Daily protein**: 120g minimum
- Use these targets when reporting nutrition data — show progress as fraction/percentage of target, call out when they're falling short or nailing it

## Health Patterns (as of Feb 26)
- Eating pattern: typically one meal/day, afternoon or evening, often junk-adjacent
- Protein consistently low except on binge days
- Weight logging very sparse — only 2 entries in 14 days
- Workout frequency very low — needs consistent nudging
- Has a home gym but says it's too cold/under-equipped, looking at proper gym membership

## Briefing Style Notes
- Weekend briefings should be chill, not work-focused
- Vary health nudges — don't repeat the same phrasing
- Connect health advice to their actual goals (gym progress, focus, weight)
- The user appreciates when good work sessions are genuinely celebrated
- Gaming binges happen — acknowledge without judging, but note the time cost

## News Rotation
- Track covered themes in briefing-context.md to avoid repetition
- Only re-mention AI model releases if there's a genuinely new one
- User interested in: AI/ML, Space (Artemis especially), Linux/Arch ecosystem, geopolitics
- Less interested in: crypto, social media drama, celebrity news
