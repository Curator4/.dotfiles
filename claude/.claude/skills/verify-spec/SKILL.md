---
name: verify-spec
description: "Forces source-verified answers when the user asks about a protocol, spec, third-party API, platform capability, or any technical fact that has an authoritative source. Quote the source before interpreting. Use when the user asks about SIA DC-03, MCP scoping, OpenAI/Anthropic/Google API capabilities, IETF/W3C specs, library APIs, or any 'does X support Y' question."
---

# Verify Spec — Source Before Answer

Default has been: answer from memory, get corrected, retry. This skill flips that to: search, find source, quote source, then interpret.

## When to invoke

Trigger when the user asks about, or you are about to assert, any of:

- A protocol or wire format (SIA DC-03, Contact ID, DTMF, gRPC details, HTTP semantics)
- A third-party API's capabilities, scopes, or auth model (OpenAI, Anthropic, Atlassian, GitHub, etc.)
- A platform configuration option (MCP scoping fields, Claude Code settings, Hyprland config)
- A library's public API or behavior (especially across versions)
- A standard or RFC

If the answer would start with "I think..." or "from memory...", invoke this instead.

## Steps

1. **Identify the authoritative source.** Official spec doc, vendor docs, RFC, source code. Not blog posts. Not stack overflow unless it's quoting a primary source.

2. **Fetch it.** Use `WebFetch` for known URLs, `WebSearch` to find one. If the user has the PDF/file locally, ask for the path rather than guess.

3. **Quote the relevant section verbatim.** A few lines, with the source URL or page. The quote is the load-bearing part of the answer — the rest is your interpretation.

4. **Then interpret.** "The spec says X, which means in our context Y."

5. **If you can't find a source, say so explicitly.** "I couldn't find an authoritative source for this — best guess is X but treat it as uncertain." Do NOT fabricate event codes, field names, mnemonics, or API capabilities to fill the gap.

## What this is NOT

- Not a replacement for code reading — if the question is about your own codebase, read the code. This is for *external* sources of truth.
- Not a tax on every factual claim — common knowledge ("Go has goroutines") doesn't need a citation. Spec-level detail does.

## Reference

This skill exists because of a recurring friction pattern: fabricated SIA event mnemonics, wrong CG1 interpretation, hallucinated `codex.agents` MCP scoping field, incorrect OpenAI ChatGPT subscription provider claim. In each case the answer was confident and wrong until the user provided the spec. Asking "what does the source say?" first is cheaper than retracting.
