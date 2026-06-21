// Syntax (compile-only) checks for the chair Workflow scripts.
//
// Workflow scripts run inside Claude's Workflow harness, which wraps the body in
// an async function (so top-level `await` and `return` are legal) and injects
// globals (agent, parallel, phase, log, args, budget, workflow). They also use
// ESM `export const meta`, which is only valid at module top level — so they can
// NOT be `node --check`'d standalone (top-level return is rejected). Until now the
// workflow files had zero coverage, so a malformed edit (an unbalanced brace or a
// broken template string in a chair prompt) would only surface at real run time.
//
// We COMPILE (do not run) each script here: strip the `export` keyword and compile
// the rest as the body of an async function whose params are the injected globals.
// Construction throws SyntaxError on a malformed body; free identifiers resolve at
// call time, not compile time, so this is purely a syntax gate.

import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const WORKFLOWS = path.resolve(HERE, "..", "workflows");
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const HARNESS_GLOBALS = ["agent", "parallel", "pipeline", "phase", "log", "args", "budget", "workflow"];

for (const file of ["synthesis.mjs", "council-synth.mjs"]) {
  test(`workflow ${file} compiles as a valid Workflow body`, () => {
    const src = fs.readFileSync(path.join(WORKFLOWS, file), "utf8").replace(/\bexport\s+const\b/g, "const");
    assert.doesNotThrow(() => new AsyncFunction(...HARNESS_GLOBALS, src), SyntaxError);
  });
}

// `crux` is the key research-applied addition to the advisory chair (the
// decision-hinge). Lock it structurally so a future prompt edit can't silently
// drop it from the output schema.
test("council-synth.mjs declares the crux field in its output schema", () => {
  const src = fs.readFileSync(path.join(WORKFLOWS, "council-synth.mjs"), "utf8");
  assert.match(src, /required:.*'crux'/, "crux is a required output");
  assert.match(src, /crux: \{ type: 'string' \}/, "crux is a declared schema property");
});
