// Test helper: write fake `grok` / `codex` / `pi` executables into a bin dir.
//
// The point of these fakes is that the CLI tests NEVER touch a real model API.
// We put these on PATH ahead of any real binaries and let the companion spawn
// them exactly as it would the real CLIs, so the full gather -> parse -> merge
// path runs offline and deterministically.
//
// Each fake's behavior is chosen at runtime from an env var (COUNCIL_FAKE_<NAME>),
// a JSON spec: { mode: "ok" | "error" | "usage" | "garbage" | "timeout" | "flood" | "flaky" | "split" | "slow", review?, bytes?, ms?, ... }.
// "slow" returns a normal ok review after `ms` (default 300) — used to observe engine concurrency.
// "flood" streams `bytes` of junk (output-size cap); "flaky" fails N times then succeeds (retry, grok only,
// needs counterFile/failTimes); "split" emits the review with a multibyte char straddling two stdout chunks
// (UTF-8 decode, grok only).
// Each fake speaks the SAME output protocol as the real CLI it stands in for:
//   - grok  : prints the review JSON object on stdout (companion runs with --output-format json)
//   - codex : writes the review JSON to the `-o <file>` path the companion passes
//   - pi    : prints a JSONL `message_end` event whose text part holds the review JSON
//
// The fakes are written as extensionless CommonJS scripts (they live in a temp dir
// with no package.json, so Node runs them as CJS — `require` is available).

import fs from "node:fs";
import path from "node:path";

const DEFAULT_REVIEW = (engine, severity) =>
  JSON.stringify({
    verdict: "needs-attention",
    summary: `${engine} default summary`,
    findings: [
      {
        severity,
        title: `${engine} default finding`,
        body: "default body",
        file: "app.js",
        line_start: 1,
        line_end: 1,
        confidence: 0.5,
        recommendation: "default recommendation",
      },
    ],
    next_steps: [],
  });

const GROK = `#!/usr/bin/env node
"use strict";
const spec = JSON.parse(process.env.COUNCIL_FAKE_GROK || '{"mode":"ok"}');
const review = spec.review ? JSON.stringify(spec.review) : ${JSON.stringify(DEFAULT_REVIEW("grok", "high"))};
if (spec.mode === "timeout") { setTimeout(function () {}, 5000); }
else if (spec.mode === "error") { process.stderr.write("grok engine error: boom"); process.exit(1); }
else if (spec.mode === "garbage") { process.stdout.write("this is not json at all"); process.exit(0); }
else if (spec.mode === "flood") { process.stdout.write("x".repeat(spec.bytes || 200000)); process.exit(0); }
else if (spec.mode === "flaky") {
  // Transient empty-output for the first \`failTimes\` invocations, then succeed.
  // Each retry is a fresh process, so invocation count is tracked in a file.
  const fsx = require("fs");
  let n = 0;
  try { n = parseInt(fsx.readFileSync(spec.counterFile, "utf8"), 10) || 0; } catch (e) {}
  n += 1;
  try { fsx.writeFileSync(spec.counterFile, String(n)); } catch (e) {}
  if (n <= (spec.failTimes || 1)) { process.exit(0); } // empty stdout -> "empty output" (retryable)
  process.stdout.write(review); process.exit(0);
}
else if (spec.mode === "split") {
  // Emit the review with a multibyte UTF-8 char straddling two stdout chunks.
  const buf = Buffer.from(review, "utf8");
  const i = buf.indexOf(0xc3); // first byte of a 2-byte char (e.g. the 'e' in cafe-acute)
  const k = i >= 0 ? i + 1 : Math.floor(buf.length / 2);
  process.stdout.write(buf.subarray(0, k));
  setTimeout(function () { process.stdout.write(buf.subarray(k)); process.exit(0); }, 25);
}
else if (spec.mode === "slow") { setTimeout(function () { process.stdout.write(review); process.exit(0); }, spec.ms || 300); }
else { process.stdout.write(review); process.exit(0); }
`;

const CODEX = `#!/usr/bin/env node
"use strict";
const fs = require("fs");
const spec = JSON.parse(process.env.COUNCIL_FAKE_CODEX || '{"mode":"ok"}');
const review = spec.review ? JSON.stringify(spec.review) : ${JSON.stringify(DEFAULT_REVIEW("codex", "medium"))};
const args = process.argv.slice(2);
const oi = args.indexOf("-o");
const outFile = oi >= 0 ? args[oi + 1] : null;
if (spec.mode === "timeout") { setTimeout(function () {}, 5000); }
else if (spec.mode === "usage") { process.stdout.write("stream error: usage limit reached"); process.exit(0); }
else if (spec.mode === "error") { process.stderr.write("codex engine error: boom"); process.exit(1); }
else if (spec.mode === "garbage") { if (outFile) fs.writeFileSync(outFile, "garbage{"); process.exit(0); }
else if (spec.mode === "flood") { if (outFile) fs.writeFileSync(outFile, "x".repeat(spec.bytes || 200000)); process.exit(0); }
else if (spec.mode === "slow") { setTimeout(function () { if (outFile) fs.writeFileSync(outFile, review); process.exit(0); }, spec.ms || 300); }
else { if (outFile) fs.writeFileSync(outFile, review); process.exit(0); }
`;

const PI = `#!/usr/bin/env node
"use strict";
const spec = JSON.parse(process.env.COUNCIL_FAKE_PI || '{"mode":"ok"}');
const review = spec.review ? JSON.stringify(spec.review) : ${JSON.stringify(DEFAULT_REVIEW("glm", "low"))};
function emit(text) {
  process.stdout.write(JSON.stringify({ type: "message_end", message: { content: [{ type: "text", text: text }] } }));
}
if (spec.mode === "timeout") { setTimeout(function () {}, 5000); }
else if (spec.mode === "error") { process.stderr.write("pi engine error: boom"); process.exit(1); }
else if (spec.mode === "garbage") { emit("no json here either"); process.exit(0); }
else if (spec.mode === "flood") { process.stdout.write("x".repeat(spec.bytes || 200000)); process.exit(0); }
else if (spec.mode === "slow") { setTimeout(function () { emit(review); process.exit(0); }, spec.ms || 300); }
else { emit(review); process.exit(0); }
`;

export function writeFakeEngines(binDir) {
  fs.mkdirSync(binDir, { recursive: true });
  for (const [name, body] of Object.entries({ grok: GROK, codex: CODEX, pi: PI })) {
    const p = path.join(binDir, name);
    fs.writeFileSync(p, body, { mode: 0o755 });
    fs.chmodSync(p, 0o755);
  }
  return binDir;
}
