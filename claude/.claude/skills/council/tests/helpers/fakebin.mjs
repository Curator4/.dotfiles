// Test helper: write fake `grok` / `codex` / `pi` executables into a bin dir.
//
// The point of these fakes is that the CLI tests NEVER touch a real model API.
// We put these on PATH ahead of any real binaries and let the companion spawn
// them exactly as it would the real CLIs, so the full gather -> parse -> merge
// path runs offline and deterministically.
//
// Each fake's behavior is chosen at runtime from an env var (COUNCIL_FAKE_<NAME>),
// a JSON spec: { mode: "ok" | "error" | "usage" | "garbage" | "timeout", review?: {...} }.
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
