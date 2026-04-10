---
name: normalize
description: "Add or update TTS text normalization rules in tts_hook.py's clean_for_speech()"
argument-hint: "<pattern> [to <replacement>] | [# <symbol> to <word>]"
---

# TTS Normalize Skill

Add, update, or remove text normalization rules in the TTS pipeline.

## User-invocable commands

- `/normalize` - Add or modify normalization rules in `clean_for_speech()`

## Usage examples

```
/normalize PR #39              → figure out what's wrong with "PR #39" and fix it
/normalize # to hash           → normalize "#" to "hash"
/normalize w/ to with          → add abbreviation rule: w/ → with
/normalize SRCU                → add acronym: SRCU → "S R C U"
/normalize RTX → R T X         → add acronym with explicit expansion
/normalize 3pm                 → handle time format
/normalize remove SRCU         → remove the SRCU normalization rule
/normalize list acronyms       → show all acronym rules currently defined
```

## Instructions

The normalization file is `~/workspace/ai/qwen-tts/tts_hook.py`, specifically the `clean_for_speech()` function.

### Step 1: Parse the user's intent

The input is flexible. Determine what they want:

1. **Explicit mapping** (`X to Y`, `X → Y`): User specified both the pattern and replacement.
2. **Example text** (`PR #39`, `3pm`, `v2.1`): User gave an example of text that TTS mispronounces. Figure out the right rule.
3. **Bare acronym/term** (`SRCU`, `NVMe`): Add a letter-by-letter or phonetic expansion.
4. **Remove** (`remove X`): Find and delete the existing rule for X.
5. **List** (`list [category]`): Show existing rules in a category.

When the intent is ambiguous, **read the current rules first** to understand what's already handled, then make a reasonable choice. If still unclear, ask.

### Step 2: Read the current state

**Always read `~/workspace/ai/qwen-tts/tts_hook.py`** before making changes. The `clean_for_speech()` function has carefully ordered sections. You MUST understand the current layout before inserting.

### Step 3: Determine where to insert

The rule sections in `clean_for_speech()` are ordered — **insertion point matters**. Here's the map:

| Section | What goes here | Anchor pattern to find |
|---------|---------------|----------------------|
| Structural | Code blocks, inline code, quotes, dashes, headers, bullets, tables, emojis | `# Text normalization for TTS` marks end of structural |
| Range dashes | `86-93` → `86 to 93` | `Range dashes:` comment |
| Identifiers | snake_case, ALL_CAPS normalization | `Bare identifiers` comment |
| Units | `3ms` → `3 milliseconds`, `5kg` → `5 kilograms` | `Compound units first` comment |
| Slang/gaming | `gg`, `afk`, `btw` | `Slang / gaming terms` comment |
| Tech terms | Pronunciation overrides for specific lowercase/mixed words | `# Tech terms` comment |
| `_ACRONYMS` dict | ALL CAPS acronyms: spell-outs, word expansions, phonetic | `_ACRONYMS = {` |
| Catch-all | Lowercases any remaining ALL CAPS word (emphasis, not acronym) | `Catch-all:` comment |
| File paths | Path normalization | `Normalize file paths` comment |
| File extensions | `.md` → `m d`, `.py` → `pee y` | `ext_pronunciations` dict |
| Abbreviations | `w/o` → `without`, rates, approximations | `Common abbreviations` comment |
| Operators | `&&`, `|`, `--flags` | `Operators` comment |
| Pre-NeMo | Paragraph breaks, large numbers | `Paragraph/newline breaks` comment |
| NeMo | Final number/date normalization | `NeMo normalization` comment |

**Rules of thumb:**
- **Acronyms** (ALL CAPS → spaced letters or word expansions) go in the `_ACRONYMS` dict — just add a key-value pair
- **Tech term pronunciations** (lowercase/mixed words like `queue` → `cue`) go with tech terms as individual `re.sub()` calls
- **Complex patterns** with regex captures (e.g. `AR-123`, plurals like `FKs`) stay as individual `re.sub()` calls above the dict
- Symbol replacements (`#` → `hash`) go after tech terms, before file paths
- Unit patterns go in the units section
- New file extensions go in the `ext_pronunciations` dict
- The catch-all at the end lowercases any ALL CAPS word NOT in the dict — no need to add emphasis words

### Step 4: Write the rule

**For acronyms/abbreviations** — add to the `_ACRONYMS` dict:

```python
_ACRONYMS = {
    # Spell-outs (letter by letter)
    "FOO": "F O O",
    # Word / phrase expansions
    "LGTM": "looks good to me",
    # Phonetic / pronunciation
    "GUI": "gooey",
    ...
}
```

**For tech term pronunciations** (lowercase words) — use `re.sub()`:

```python
text = re.sub(r"\babbrev\b", "full word", text, flags=re.IGNORECASE)
```

**For complex patterns** (regex captures, plurals, compounds) — use `re.sub()`:

```python
text = re.sub(r"\bFOOs\b", "foo bars", text, flags=re.IGNORECASE)
text = re.sub(r"\bFOO[-‑ ](\d+)\b", r"F O O \1", text, flags=re.IGNORECASE)
```

### Step 5: Edit the file

Use the Edit tool to insert the new rule. **Be precise:**
- For dict entries: add to the appropriate section (spell-outs, word expansions, or phonetic) inside `_ACRONYMS`
- For `re.sub()` rules: match surrounding indentation (4 spaces inside `clean_for_speech`)
- Don't duplicate existing rules — if a similar rule exists, update it instead

### Step 6: Verify

After editing, read back the modified section to confirm:
- The rule is syntactically valid Python
- It's in the right position relative to other rules
- No existing rules were disturbed

### Step 7: Confirm to the user

Report what you added/changed concisely:
- The pattern and replacement
- Where it was inserted (which section)
- Any ordering considerations

Do NOT test-run the TTS pipeline — just confirm the edit.
