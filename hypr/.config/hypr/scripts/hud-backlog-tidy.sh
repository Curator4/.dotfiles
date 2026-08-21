#!/usr/bin/env bash
# Mop-up: re-file `## Captured` strays into the category sections. Captures
# classify themselves at input time now (hud-capture.sh passes --section;
# LLM writers file directly), so this inbox only collects genuinely-unsure
# items — rare. Manual on purpose (`backlog tidy`); no timer, per ADR 0008's
# no-scheduled-generation rule.
#
# Shape: one Haiku call classifies each inbox item (time | admin | home);
# the file surgery itself is deterministic Python — lines move verbatim,
# nothing is rewritten, the result must be a pure permutation of the input
# or the write is refused. Backup lands at backlog.md.bak-tidy.
set -uo pipefail

BACKLOG=${BACKLOG:-/home/curator/workspace/ai/household-oc/data/backlog.md}
HUD=${HUD:-/home/curator/workspace/hud/hud}
claude=/home/curator/.local/bin/claude
llmdir="$HOME/.local/state/hud/llm"
model="claude-haiku-4-5-20251001"
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/hud
LOCK=$STATE/backlog-tidy.lock

mkdir -p "$STATE" 2>/dev/null
if ! mkdir "$LOCK" 2>/dev/null; then
    notify-send -t 3000 backlog "tidy already running" 2>/dev/null || true
    exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

# --- 1. Inbox items, in file order ------------------------------------------
mapfile -t items < <(awk '
    /^## Captured$/ {inbox=1; next}
    /^## /          {inbox=0}
    inbox && /^- \[ \] /' "$BACKLOG")
if [ "${#items[@]}" -eq 0 ]; then
    notify-send -t 3000 backlog "inbox empty — nothing to tidy" 2>/dev/null || true
    exit 0
fi
n=${#items[@]}

# --- 2. One Haiku call: classify each item -----------------------------------
# Unsure items are simply not listed; they stay in the inbox.
numbered=$(for i in "${!items[@]}"; do printf '%d. %s\n' "$((i + 1))" "${items[$i]}"; done)
prompt="You re-file household backlog items. Destination sections:
- time: Time-sensitive — deadline-driven; a hard date or explicit deadline wording (often a trailing \"@ YYYY-MM-DD\").
- admin: Personal admin — the operator's personal working items: errands, money, subscriptions, learning goals, courses, research/exploration sessions, content curation.
- home: Home — the machine and household: system, hardware, desktop environment, rice, keybinds, tooling, agents, anything that is code/config on this box.
Classify EVERY item. When torn between admin and home: touch code or config on this machine → home; otherwise admin. When unsure between time and others, only pick time if a date is explicit.
Reply with ONLY minified JSON: {\"moves\":[{\"i\":<number>,\"s\":\"time|admin|home\"}]} — one entry per item, all $n items.
Items:
$numbered"

json=$(cd "$llmdir" && HUD_SUMMARIZING=1 "$claude" -p --model "$model" "$prompt" 2>/dev/null |
    tr -d '\n' | grep -o '{.*}' | head -1)
if [ -z "$json" ]; then
    notify-send -t 4000 backlog "tidy failed — no classifier output" 2>/dev/null || true
    exit 1
fi

# Drop anything malformed: out-of-range index, unknown section, duplicate i.
moves=$(printf '%s' "$json" | jq -c --argjson n "$n" '
    [.moves[]?
     | select((.i | type) == "number" and .i >= 1 and .i <= ($n | floor))
     | select(.s == "time" or .s == "admin" or .s == "home")
     | {i: (.i | floor), s: .s}]
    | unique_by(.i)') || exit 1

# --- 3. Deterministic move + validation --------------------------------------
summary=$(
    BACKLOG="$BACKLOG" MOVES="$moves" python3 - <<'PY'
import json, os, re, shutil, sys

path = os.environ["BACKLOG"]
moves = {int(m["i"]): m["s"] for m in json.loads(os.environ["MOVES"])}
secmap = {"time": "Time-sensitive", "admin": "Personal admin", "home": "Home"}

lines = open(path).read().split("\n")

# Section spans: (name, start). Section runs to the next "## " or EOF.
starts = [(l[3:].strip(), i) for i, l in enumerate(lines) if l.startswith("## ")]
by_name = dict(starts)

def span_end(start):
    return next((s for _, s in starts if s > start), len(lines))

item_re = re.compile(r"^- \[ \] ")

cap = by_name.get("Captured")
if cap is None:
    sys.exit("no Captured section")
cap_items = [i for i in range(cap + 1, span_end(cap)) if item_re.match(lines[i])]

# Validate every classified index before touching anything.
move_at = {}  # line index -> target section name
for k, s in moves.items():
    if not (1 <= k <= len(cap_items)):
        sys.exit(f"index {k} out of range (1..{len(cap_items)})")
    if s not in secmap:
        sys.exit(f"unknown section {s!r}")
    move_at[cap_items[k - 1]] = secmap[s]

def insertion_point(name):
    """After the section's last item line; else after its leading
    description-comment block. Original coordinates — targets all
    precede Captured, so inserts fire before removals."""
    start = by_name[name]
    end = span_end(start)
    last_item = None
    for i in range(start + 1, end):
        if item_re.match(lines[i]):
            last_item = i
    if last_item is not None:
        return last_item + 1
    j = start
    for i in range(start + 1, end):
        if lines[i].startswith("<!--"):
            j = i
    return j + 1

inserts = {}
for li, target in sorted(move_at.items()):
    inserts.setdefault(insertion_point(target), []).append(lines[li])

out = []
for i, line in enumerate(lines):
    if i in inserts:
        out.extend(inserts[i])
    if i in move_at:
        continue
    out.append(line)

# Refuse the write unless the result is a pure permutation of the input.
if sorted(out) != sorted(lines) or len(out) != len(lines):
    sys.exit("validation failed: result is not a permutation of the input")

shutil.copy2(path, path + ".bak-tidy")
open(path, "w").write("\n".join(out))

counts = {}
for target in move_at.values():
    counts[target] = counts.get(target, 0) + 1
moved = ", ".join(f"{v} → {k}" for k, v in sorted(counts.items())) or "0"
print(f"{moved}; {len(cap_items) - len(move_at)} stayed")
PY
) || {
    notify-send -t 5000 backlog "tidy refused — $summary" 2>/dev/null || true
    exit 1
}

# --- 4. Refresh the card if it is open ----------------------------------------
if eww active-windows 2>/dev/null | grep -q '^backlog:'; then
    rows=$("$HUD" backlog --json 2>/dev/null || echo "[]")
    eww update backlog_rows="$rows" >/dev/null
fi
notify-send -t 4000 "backlog tidied" "$summary" 2>/dev/null || true
