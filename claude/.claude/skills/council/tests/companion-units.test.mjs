// Unit tests for the pure helpers in council-companion.mjs.
// No subprocess, no network — these import the module directly and exercise the
// parsing / normalization / merge logic that turns untrusted model output into a
// structured review. Run: `node --test tests/`.

import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  firstLine,
  stripFences,
  extractJson,
  normSeverity,
  normReview,
  merge,
  piAssistantText,
  parseArgs,
  getFlagValue,
  interpolate,
} from "../scripts/council-companion.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));

// ---------- firstLine ----------
test("firstLine returns the first non-empty trimmed line", () => {
  assert.equal(firstLine("  \n\n  hello \n world"), "hello");
  assert.equal(firstLine("only"), "only");
  assert.equal(firstLine(""), "");
  assert.equal(firstLine(null), "");
});

// ---------- stripFences ----------
test("stripFences unwraps ```json fences, bare fences, and plain text", () => {
  assert.equal(stripFences("```json\n{\"a\":1}\n```"), '{"a":1}');
  assert.equal(stripFences("```\n{\"a\":1}\n```"), '{"a":1}');
  assert.equal(stripFences("   {\"a\":1}   "), '{"a":1}');
  assert.equal(stripFences("plain text"), "plain text");
});

// ---------- extractJson ----------
test("extractJson parses bare, fenced, and embedded JSON", () => {
  assert.deepEqual(extractJson('{"a":1}'), { a: 1 });
  assert.deepEqual(extractJson("```json\n{\"a\":2}\n```"), { a: 2 });
  assert.deepEqual(extractJson('prefix noise {"a":3} trailing words'), { a: 3 });
});

test("extractJson throws on output with no JSON object", () => {
  assert.throws(() => extractJson("there is no json here"), /could not parse JSON/);
  assert.throws(() => extractJson(""), /could not parse JSON/);
});

// ---------- normSeverity ----------
test("normSeverity canonicalizes case, aliases, and unknowns", () => {
  assert.equal(normSeverity("CRITICAL "), "critical");
  assert.equal(normSeverity("blocker"), "critical");
  assert.equal(normSeverity("severe"), "critical");
  assert.equal(normSeverity("major"), "high");
  assert.equal(normSeverity("error"), "high");
  assert.equal(normSeverity("warn"), "medium");
  assert.equal(normSeverity("moderate"), "medium");
  assert.equal(normSeverity("nit"), "low");
  assert.equal(normSeverity("info"), "low");
  assert.equal(normSeverity("banana"), "medium"); // unknown -> medium
  assert.equal(normSeverity(null), "medium");
});

// ---------- normReview ----------
test("normReview shapes findings and fills defaults", () => {
  const r = normReview({
    verdict: "needs-attention",
    summary: "  s  ",
    findings: [
      { severity: "BLOCKER", title: "T", body: "B", file: "f.js", line_start: 4, line_end: 7, confidence: 0.9, recommendation: "fix" },
      { body: "only a body" }, // missing title -> title falls back to body; defaults elsewhere
    ],
    next_steps: ["a", "b"],
  });
  assert.equal(r.verdict, "needs-attention");
  assert.equal(r.summary, "s");
  assert.equal(r.findings.length, 2);
  assert.equal(r.findings[0].severity, "critical"); // BLOCKER normalized
  assert.equal(r.findings[0].line_start, 4);
  assert.equal(r.findings[1].title, "only a body");
  assert.equal(r.findings[1].file, "?");
  assert.equal(r.findings[1].line_start, null); // non-finite -> null
  assert.deepEqual(r.next_steps, ["a", "b"]);
});

test("normReview derives verdict and tolerates junk input", () => {
  assert.equal(normReview({ findings: [{ severity: "low" }] }).verdict, "needs-attention");
  assert.equal(normReview({}).verdict, "approve");
  assert.equal(normReview({ verdict: "approve", findings: [{ severity: "low" }] }).verdict, "approve");
  for (const junk of [null, undefined, "a string", 42, []]) {
    const r = normReview(junk);
    assert.equal(r.verdict, "approve");
    assert.deepEqual(r.findings, []);
    assert.deepEqual(r.next_steps, []);
  }
});

// ---------- merge (consensus tagging + dedup + severity reconciliation) ----------
test("merge dedupes same finding across engines, tags consensus, keeps strongest severity", () => {
  const results = [
    {
      ok: true,
      id: "grok",
      label: "Grok",
      review: {
        verdict: "needs-attention",
        summary: "g",
        findings: [{ severity: "high", title: "SQL Injection", body: "b", file: "app.js", line_start: 1, line_end: 1, confidence: 0.8, recommendation: "r1" }],
        next_steps: ["ns1"],
      },
    },
    {
      ok: true,
      id: "glm",
      label: "GLM",
      review: {
        verdict: "approve",
        summary: "gl",
        findings: [
          { severity: "critical", title: "sql injection", body: "b2", file: "app.js", line_start: 2, line_end: 2, confidence: 0.6, recommendation: "r2" },
          { severity: "medium", title: "XSS", body: "x", file: "b.js", line_start: 3, line_end: 3, confidence: 0.4, recommendation: "r3" },
        ],
        next_steps: ["ns2", "ns1"],
      },
    },
    { ok: false, id: "codex", label: "Codex", error: "usage limit" },
  ];
  const m = merge(results);
  assert.equal(m.verdict, "needs-attention");
  assert.equal(m.findings.length, 2);
  const sql = m.findings[0];
  assert.equal(sql.severity, "critical"); // critical beats high
  assert.deepEqual(sql.engines, ["grok", "glm"]);
  assert.equal(sql.file, "app.js");
  assert.equal(m.findings[1].title, "XSS");
  assert.deepEqual(m.findings[1].engines, ["glm"]);
  assert.deepEqual(m.next, ["ns1", "ns2"]); // deduped, union
});

test("merge yields verdict 'unknown' when no engine succeeded", () => {
  const m = merge([{ ok: false, id: "grok", error: "down" }]);
  assert.equal(m.verdict, "unknown");
  assert.deepEqual(m.findings, []);
});

// ---------- piAssistantText (JSONL event parsing) ----------
test("piAssistantText extracts the last non-empty assistant message", () => {
  const stream = [
    '{"type":"message_start"}',
    "garbage non-json line",
    "",
    '{"type":"message_end","message":{"content":[{"type":"text","text":"hello"},{"type":"tool"},{"type":"text","text":"world"}]}}',
  ].join("\n");
  assert.equal(piAssistantText(stream), "hello\nworld");
});

test("piAssistantText keeps the last non-empty message and supports content fallback", () => {
  const stream = [
    '{"type":"message_end","message":{"content":[{"type":"text","text":"first"}]}}',
    '{"type":"message_end","message":{"content":[]}}',
  ].join("\n");
  assert.equal(piAssistantText(stream), "first");
  assert.equal(piAssistantText('{"type":"message_end","content":[{"type":"text","text":"viaContent"}]}'), "viaContent");
  assert.equal(piAssistantText("nothing parseable here"), "");
});

// ---------- parseArgs / getFlagValue ----------
test("parseArgs handles --base/--scope (space and = forms) and collects focus", () => {
  assert.deepEqual(parseArgs(["--base", "main", "foo", "bar"]), { scope: null, base: "main", focus: ["foo", "bar"] });
  assert.deepEqual(parseArgs(["--scope=working-tree", "--base=dev"]), { scope: "working-tree", base: "dev", focus: [] });
  assert.deepEqual(parseArgs([]), { scope: null, base: null, focus: [] });
});

test("getFlagValue reads --flag value and --flag=value", () => {
  assert.equal(getFlagValue(["--brief-file", "/p"], "--brief-file"), "/p");
  assert.equal(getFlagValue(["--brief-file=/q", "--json"], "--brief-file"), "/q");
  assert.equal(getFlagValue(["--json"], "--brief-file"), undefined);
});

// ---------- interpolate (and its injection-safety property) ----------
test("interpolate substitutes placeholders and blanks missing keys", () => {
  assert.equal(interpolate("a {{X}} b", { X: "1" }), "a 1 b");
  assert.equal(interpolate("{{X}}{{Y}}", { X: "p" }), "p");
});

test("interpolate does NOT re-expand substituted content or honor $-replacement patterns", () => {
  // A diff/topic that itself contains {{...}} must be inserted literally, not
  // treated as another placeholder (single-pass replace).
  assert.equal(interpolate("{{DIFF}}", { DIFF: "{{SECRET}}" }), "{{SECRET}}");
  // Function-replacer means $&, $1, $` in the value are inserted literally.
  assert.equal(interpolate("{{DIFF}}", { DIFF: "$& $1 $`" }), "$& $1 $`");
});

// ---------- schema file integrity ----------
test("review-output.schema.json is valid and constrains severity/required fields", () => {
  const schema = JSON.parse(fs.readFileSync(path.join(HERE, "..", "schemas", "review-output.schema.json"), "utf8"));
  assert.deepEqual(schema.required, ["verdict", "summary", "findings", "next_steps"]);
  assert.deepEqual(schema.properties.verdict.enum, ["approve", "needs-attention"]);
  assert.deepEqual(schema.properties.findings.items.properties.severity.enum, ["critical", "high", "medium", "low"]);
});
