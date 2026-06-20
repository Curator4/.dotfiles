// End-to-end CLI tests for council-companion.mjs with the external model CLIs
// MOCKED. Fake `grok` / `codex` / `pi` binaries are placed on PATH (see
// helpers/fakebin.mjs) and the companion is spawned against a throwaway git repo.
// No real model API is ever contacted. Run: `node --test tests/`.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile, execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { writeFakeEngines } from "./helpers/fakebin.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const COMPANION = path.resolve(HERE, "..", "scripts", "council-companion.mjs");

let repo;
let binDir;
const tmpDirs = [];

function mkdtemp(prefix) {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  tmpDirs.push(d);
  return d;
}

function makeDirtyRepo() {
  const dir = mkdtemp("council-repo-");
  const g = (args) => execFileSync("git", args, { cwd: dir, stdio: "ignore" });
  g(["init", "-q"]);
  g(["config", "user.email", "test@example.com"]);
  g(["config", "user.name", "Council Test"]);
  g(["config", "commit.gpgsign", "false"]);
  g(["config", "core.hooksPath", "/nonexistent-council-test-hooks"]); // isolate from any global hooks
  fs.writeFileSync(path.join(dir, "app.js"), "const x = 1;\n");
  g(["add", "-A"]);
  g(["commit", "-q", "-m", "init"]);
  // Introduce a working-tree change so scope=auto resolves to working-tree.
  fs.writeFileSync(path.join(dir, "app.js"), "const x = 1;\nconst y = 2;\n");
  return dir;
}

function runCompanion(args, env) {
  return new Promise((resolve) => {
    execFile(
      process.execPath,
      [COMPANION, ...args],
      { cwd: repo, env, maxBuffer: 32 * 1024 * 1024 },
      (err, stdout, stderr) => {
        resolve({ code: err && typeof err.code === "number" ? err.code : err ? 1 : 0, stdout: stdout || "", stderr: stderr || "" });
      }
    );
  });
}

function baseEnv(fakes, extra = {}) {
  const env = {
    ...process.env,
    PATH: `${binDir}${path.delimiter}${process.env.PATH || ""}`,
    ...extra,
  };
  if (fakes.grok) env.COUNCIL_FAKE_GROK = JSON.stringify(fakes.grok);
  if (fakes.codex) env.COUNCIL_FAKE_CODEX = JSON.stringify(fakes.codex);
  if (fakes.pi) env.COUNCIL_FAKE_PI = JSON.stringify(fakes.pi);
  return env;
}

const R_GROK = {
  verdict: "needs-attention",
  summary: "grok take",
  findings: [{ severity: "high", title: "SQL Injection", body: "param it", file: "app.js", line_start: 2, line_end: 2, confidence: 0.8, recommendation: "use params" }],
  next_steps: ["fix sql"],
};
// pi(GLM) raises the SAME SQL finding (consensus) plus a distinct XSS one.
const R_PI = {
  verdict: "needs-attention",
  summary: "glm take",
  findings: [
    { severity: "critical", title: "SQL Injection", body: "same issue", file: "app.js", line_start: 2, line_end: 2, confidence: 0.7, recommendation: "use params" },
    { severity: "medium", title: "XSS", body: "escape output", file: "app.js", line_start: 1, line_end: 1, confidence: 0.5, recommendation: "escape" },
  ],
  next_steps: ["fix xss"],
};

before(() => {
  binDir = writeFakeEngines(mkdtemp("council-bin-"));
  repo = makeDirtyRepo();
});

after(() => {
  for (const d of tmpDirs) {
    try {
      fs.rmSync(d, { recursive: true, force: true });
    } catch {
      /* ignore */
    }
  }
});

test("council --json: merges survivors, tags engines, skips the failed one", async () => {
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, pi: { mode: "ok", review: R_PI }, codex: { mode: "usage" } });
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.match(out.diff, /const y = 2/); // working-tree diff captured
  assert.ok(out.repoPath.includes("council-repo"));
  assert.equal(out.findings.length, 3); // grok:1 + glm:2 (flat, not merged in --json)
  assert.deepEqual(out.findings.map((f) => f.engine).sort(), ["glm", "glm", "grok"]);
  assert.equal(out.skipped.length, 1);
  assert.equal(out.skipped[0].id, "codex");
  assert.match(out.skipped[0].error, /usage limit/i);
});

test("council (human render): shows verdict, consensus tag, and the skip line", async () => {
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, pi: { mode: "ok", review: R_PI }, codex: { mode: "usage" } });
  const res = await runCompanion(["council"], env);
  assert.equal(res.code, 0, res.stderr);
  assert.match(res.stdout, /Verdict: NEEDS-ATTENTION/);
  assert.ok(res.stdout.includes("[grok, glm]"), "SQL Injection should be tagged as raised by both engines");
  assert.match(res.stdout, /Codex skipped/);
  assert.match(res.stdout, /usage limit/i);
  assert.ok(res.stdout.includes("XSS"));
});

test("council --json: all engines unavailable degrades gracefully (exit 0, empty findings)", async () => {
  const env = baseEnv({ grok: { mode: "error" }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.equal(out.findings.length, 0);
  assert.equal(out.skipped.length, 3);
});

test("council --json: a hung engine is killed by the timeout and skipped", async () => {
  const env = baseEnv(
    { grok: { mode: "timeout" }, codex: { mode: "ok" }, pi: { mode: "ok" } },
    { COUNCIL_TIMEOUT_MS: "500" }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  const grokSkip = out.skipped.find((s) => s.id === "grok");
  assert.ok(grokSkip, "grok should be skipped");
  assert.match(grokSkip.error, /timed out/i);
  const engines = new Set(out.findings.map((f) => f.engine));
  assert.ok(engines.has("codex") && engines.has("glm"), "survivors still produce findings");
});

test("council --json: garbage / unparseable output from every engine is skipped, not crashed", async () => {
  const env = baseEnv({ grok: { mode: "garbage" }, codex: { mode: "garbage" }, pi: { mode: "garbage" } });
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.equal(out.findings.length, 0);
  assert.equal(out.skipped.length, 3);
});

test("council-brief --json: fans the brief out to every engine for a prose take", async () => {
  const briefFile = path.join(mkdtemp("council-brief-"), "brief.md");
  fs.writeFileSync(briefFile, "Should we use Postgres or SQLite for the event store?");
  const env = baseEnv({ grok: { mode: "ok" }, codex: { mode: "ok" }, pi: { mode: "ok" } });
  const res = await runCompanion(["council-brief", "--brief-file", briefFile, "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.equal(out.takes.length, 3);
  assert.equal(out.skipped.length, 0);
  for (const t of out.takes) assert.ok(t.text && t.text.length > 0, `engine ${t.engine} returned a non-empty take`);
});
