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

// A clean committed repo (one commit, nothing dirty). Tests dirty/branch it as needed.
function makeRepo() {
  const dir = mkdtemp("council-repo2-");
  const g = (args) => execFileSync("git", args, { cwd: dir, stdio: "ignore" });
  g(["init", "-q"]);
  g(["config", "user.email", "test@example.com"]);
  g(["config", "user.name", "Council Test"]);
  g(["config", "commit.gpgsign", "false"]);
  g(["config", "core.hooksPath", "/nonexistent-council-test-hooks"]);
  fs.writeFileSync(path.join(dir, "app.js"), "const x = 1;\n");
  g(["add", "-A"]);
  g(["commit", "-q", "-m", "init"]);
  return dir;
}

function gitIn(dir, args) {
  return execFileSync("git", args, { cwd: dir, encoding: "utf8" }).trim();
}

function runCompanion(args, env, cwd = repo) {
  return new Promise((resolve) => {
    execFile(
      process.execPath,
      [COMPANION, ...args],
      { cwd, env, maxBuffer: 32 * 1024 * 1024 },
      (err, stdout, stderr) => {
        resolve({ code: err && typeof err.code === "number" ? err.code : err ? 1 : 0, stdout: stdout || "", stderr: stderr || "" });
      }
    );
  });
}

function baseEnv(fakes, extra = {}) {
  const env = { ...process.env };
  // Isolate from any ambient COUNCIL_* config so tests are deterministic.
  for (const k of Object.keys(env)) if (k.startsWith("COUNCIL_")) delete env[k];
  env.PATH = `${binDir}${path.delimiter}${process.env.PATH || ""}`;
  Object.assign(env, extra);
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

// ---------- security hardening ----------

test("council --json: an engine flooding stdout is capped (SIGKILL) and skipped", async () => {
  const env = baseEnv(
    { grok: { mode: "flood" }, codex: { mode: "ok" }, pi: { mode: "ok" } },
    { COUNCIL_MAX_OUTPUT_BYTES: "4096" }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  const grokSkip = out.skipped.find((s) => s.id === "grok");
  assert.ok(grokSkip, "flooding grok should be skipped");
  assert.match(grokSkip.error, /size cap|exceeded/i);
  const engines = new Set(out.findings.map((f) => f.engine));
  assert.ok(engines.has("codex") && engines.has("glm"), "survivors still produce findings");
});

test("council --json: codex overflowing its -o output file is capped and skipped", async () => {
  const env = baseEnv(
    { grok: { mode: "ok", review: R_GROK }, codex: { mode: "flood" }, pi: { mode: "ok", review: R_PI } },
    { COUNCIL_MAX_OUTPUT_BYTES: "4096" }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  const codexSkip = out.skipped.find((s) => s.id === "codex");
  assert.ok(codexSkip, "codex writing an oversized file should be skipped");
  assert.match(codexSkip.error, /size cap|exceeded/i);
});

test("COUNCIL_DEBUG dumps go to a private 0700 dir, not fixed world-readable /tmp paths", async () => {
  const env = baseEnv(
    { grok: { mode: "ok", review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } },
    { COUNCIL_DEBUG: "1" }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const m = res.stderr.match(/COUNCIL_DEBUG dumps -> (\S+)/);
  assert.ok(m, "debug dir should be announced on stderr");
  const dir = m[1];
  tmpDirs.push(dir);
  assert.match(dir, /council-debug-/, "dump dir should be a private mkdtemp dir");
  assert.ok(fs.existsSync(path.join(dir, "grok-out.txt")), "grok stdout dump should be present");
  assert.equal(fs.statSync(dir).mode & 0o077, 0, "debug dir must not be group/world accessible");
});

test("council rejects a --base ref beginning with '-' (argument-injection guard)", async () => {
  const env = baseEnv({ grok: { mode: "ok" }, codex: { mode: "ok" }, pi: { mode: "ok" } });
  const res = await runCompanion(["council", "--base", "--evil-option", "--json"], env);
  assert.notEqual(res.code, 0, "an option-shaped base ref should abort");
  assert.match(res.stderr, /unsafe .*base|must not start/i);
});

// ---------- reliability: engine concurrency (COUNCIL_CONCURRENCY) ----------

test("engines run concurrently by default; COUNCIL_CONCURRENCY=1 serializes (same results)", async () => {
  const SLEEP = 300;
  const fakes = {
    grok: { mode: "slow", ms: SLEEP, review: R_GROK },
    codex: { mode: "slow", ms: SLEEP },
    pi: { mode: "slow", ms: SLEEP, review: R_PI },
  };
  const run = async (extra) => {
    const t0 = Date.now();
    const res = await runCompanion(["council", "--json"], baseEnv(fakes, extra));
    const ms = Date.now() - t0;
    assert.equal(res.code, 0, res.stderr);
    return { ms, out: JSON.parse(res.stdout) };
  };
  const parallel = await run({});
  const sequential = await run({ COUNCIL_CONCURRENCY: "1" });
  const engines = (o) => o.out.findings.map((f) => f.engine).sort();
  assert.deepEqual(engines(parallel), engines(sequential), "same findings regardless of concurrency");
  assert.ok(parallel.out.findings.length >= 3, "all three engines contributed");
  // Sequential is ~3 sleeps, parallel ~1; the gap must exceed at least one sleep
  // (true headroom is ~2x SLEEP, so this is robust to per-spawn overhead/jitter).
  assert.ok(
    sequential.ms - parallel.ms > SLEEP,
    `expected concurrency speedup > ${SLEEP}ms (parallel=${parallel.ms}ms, sequential=${sequential.ms}ms)`
  );
});

// ---------- robustness: multibyte UTF-8 output split across stdout chunks ----------

test("council --json: a multibyte char split across stdout chunks is decoded, not mangled", async () => {
  const review = {
    verdict: "needs-attention",
    summary: "résumé café",
    findings: [
      { severity: "high", title: "café résumé ☕ piñata", body: "naïve coöperation", file: "app.js", line_start: 1, line_end: 1, confidence: 0.5, recommendation: "fix" },
    ],
    next_steps: [],
  };
  // grok 'split' mode writes the review with a multibyte char straddling two chunks.
  const env = baseEnv({ grok: { mode: "split", review }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  const grokFindings = out.findings.filter((f) => f.engine === "grok");
  assert.equal(grokFindings.length, 1, "the finding parsed despite the mid-character chunk split");
  assert.equal(grokFindings[0].title, "café résumé ☕ piñata", "multibyte chars intact (no replacement chars)");
});

// ---------- reliability: transient-failure retry ----------

test("council --json: a transient empty-output failure is retried and recovers", async () => {
  const counter = path.join(mkdtemp("council-counter-"), "n");
  const env = baseEnv(
    { grok: { mode: "flaky", counterFile: counter, failTimes: 1, review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } },
    { COUNCIL_RETRIES: "1", COUNCIL_RETRY_DELAY_MS: "0" }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.ok(out.findings.some((f) => f.engine === "grok"), "grok should recover via retry");
  assert.equal(out.skipped.find((s) => s.id === "grok"), undefined, "recovered engine must not be in skipped");
  assert.equal(fs.readFileSync(counter, "utf8"), "2", "grok should be invoked twice (1 empty + 1 retry)");
});

test("council --json: a non-retryable error is NOT retried (single attempt)", async () => {
  // COUNCIL_RETRIES=2, but a hard error (not the empty-output family) must abort immediately.
  const env = baseEnv(
    { grok: { mode: "error" }, codex: { mode: "error" }, pi: { mode: "ok", review: R_PI } },
    { COUNCIL_RETRIES: "2", COUNCIL_RETRY_DELAY_MS: "0" }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  const grokSkip = out.skipped.find((s) => s.id === "grok");
  assert.ok(grokSkip, "grok should be skipped");
  assert.equal(grokSkip.attempts, 1, "a hard error must not be retried");
});

test("council (human render): reports the attempt count for an engine that retried", async () => {
  const counter = path.join(mkdtemp("council-counter-"), "n");
  const env = baseEnv(
    { grok: { mode: "flaky", counterFile: counter, failTimes: 1, review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } },
    { COUNCIL_RETRIES: "1", COUNCIL_RETRY_DELAY_MS: "0" }
  );
  const res = await runCompanion(["council"], env);
  assert.equal(res.code, 0, res.stderr);
  assert.match(res.stdout, /2 attempts/, "the status line should note the retry");
});

// ---------- capability: configurable engine roster (COUNCIL_ENGINES) ----------

test("COUNCIL_ENGINES narrows the council to the listed subset", async () => {
  const env = baseEnv(
    { grok: { mode: "ok", review: R_GROK }, codex: { mode: "ok" }, pi: { mode: "ok", review: R_PI } },
    { COUNCIL_ENGINES: "grok,glm" }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  const engines = new Set(out.findings.map((f) => f.engine));
  assert.ok(engines.has("grok") && engines.has("glm"), "listed engines run");
  assert.ok(!engines.has("codex"), "unlisted engine does not run");
  assert.equal(out.skipped.find((s) => s.id === "codex"), undefined, "out-of-roster engine is neither run nor skipped");
});

test("COUNCIL_ENGINES=grok runs only grok", async () => {
  const env = baseEnv(
    { grok: { mode: "ok", review: R_GROK }, codex: { mode: "ok" }, pi: { mode: "ok" } },
    { COUNCIL_ENGINES: "grok" }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.deepEqual([...new Set(out.findings.map((f) => f.engine))], ["grok"]);
  assert.equal(out.skipped.length, 0);
});

test("COUNCIL_ENGINES drops unknown ids with a warning, runs the valid ones", async () => {
  const env = baseEnv(
    { grok: { mode: "ok", review: R_GROK }, codex: { mode: "ok" }, pi: { mode: "ok" } },
    { COUNCIL_ENGINES: "grok, bogus" }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  assert.match(res.stderr, /unknown engine.*bogus/i);
  const out = JSON.parse(res.stdout);
  assert.deepEqual([...new Set(out.findings.map((f) => f.engine))], ["grok"]);
});

test("blank COUNCIL_ENGINES falls back to the enabled defaults (all engines)", async () => {
  const env = baseEnv(
    { grok: { mode: "ok", review: R_GROK }, codex: { mode: "ok" }, pi: { mode: "ok", review: R_PI } },
    { COUNCIL_ENGINES: "   " }
  );
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  const engines = new Set(out.findings.map((f) => f.engine));
  assert.ok(engines.has("grok") && engines.has("codex") && engines.has("glm"), "blank roster -> all enabled defaults");
});

test("COUNCIL_ENGINES also scopes the open-brief fan-out", async () => {
  const briefFile = path.join(mkdtemp("council-brief-"), "brief.md");
  fs.writeFileSync(briefFile, "Postgres or SQLite?");
  const env = baseEnv(
    { grok: { mode: "ok" }, codex: { mode: "ok" }, pi: { mode: "ok" } },
    { COUNCIL_ENGINES: "glm" }
  );
  const res = await runCompanion(["council-brief", "--brief-file", briefFile, "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.deepEqual(out.takes.map((t) => t.engine), ["glm"]);
  assert.equal(out.skipped.length, 0);
});

// ---------- diff collection (collectTarget) + single-engine mode ----------

test("review errors out when not inside a git repository", async () => {
  const nonRepo = mkdtemp("council-nonrepo-");
  const env = baseEnv({ grok: { mode: "ok" }, codex: { mode: "ok" }, pi: { mode: "ok" } });
  const res = await runCompanion(["council", "--json"], env, nonRepo);
  assert.notEqual(res.code, 0, "should fail outside a git repo");
  assert.match(res.stderr, /not inside a git repository/i);
});

test("working-tree scope appends untracked files to the reviewed diff", async () => {
  const r = makeRepo();
  fs.writeFileSync(path.join(r, "NEWFILE_untracked.txt"), "a brand new file\n");
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--json"], env, r);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.match(out.diff, /Untracked files/, "untracked files are surfaced to reviewers");
  assert.match(out.diff, /NEWFILE_untracked\.txt/);
});

test("branch scope diffs the given --base ref against HEAD", async () => {
  const r = makeRepo();
  const base = gitIn(r, ["rev-parse", "HEAD"]);
  fs.writeFileSync(path.join(r, "app.js"), "const x = 1;\n// COMMIT_TWO_MARKER\n");
  execFileSync("git", ["add", "-A"], { cwd: r, stdio: "ignore" });
  execFileSync("git", ["commit", "-q", "-m", "second"], { cwd: r, stdio: "ignore" });
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--scope", "branch", "--base", base, "--json"], env, r);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.match(out.diff, /COMMIT_TWO_MARKER/, "branch diff contains the second commit's change");
  assert.ok(out.findings.some((f) => f.engine === "grok"), "pipeline ran on the branch diff");
});

test("clean working tree (scope auto -> branch) yields an empty review", async () => {
  const r = makeRepo(); // committed, nothing dirty
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "ok" }, pi: { mode: "ok" } });
  const res = await runCompanion(["council", "--json"], env, r);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.equal(out.diff, "", "no changes -> empty diff");
  assert.equal(out.findings.length, 0);
});

test("grok-review single mode runs only grok (--json)", async () => {
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "ok" }, pi: { mode: "ok" } });
  const res = await runCompanion(["grok-review", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.deepEqual([...new Set(out.findings.map((f) => f.engine))], ["grok"], "only grok runs in single mode");
});

test("staged scope reviews only the staged diff (git diff --cached), not unstaged work", async () => {
  const r = makeRepo();
  // Stage one change...
  fs.writeFileSync(path.join(r, "app.js"), "const x = 1;\n// STAGED_CHANGE\n");
  execFileSync("git", ["add", "app.js"], { cwd: r, stdio: "ignore" });
  // ...then make a further unstaged change on top.
  fs.writeFileSync(path.join(r, "app.js"), "const x = 1;\n// STAGED_CHANGE\n// UNSTAGED_CHANGE\n");
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--scope", "staged", "--json"], env, r);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.match(out.diff, /STAGED_CHANGE/, "staged change is reviewed");
  assert.ok(!out.diff.includes("UNSTAGED_CHANGE"), "unstaged change is excluded");
  assert.ok(out.findings.some((f) => f.engine === "grok"), "pipeline ran on the staged diff");
});

test("staged scope with nothing staged yields an empty review", async () => {
  const r = makeRepo();
  fs.writeFileSync(path.join(r, "app.js"), "const x = 1;\n// unstaged only\n"); // modified, not added
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "ok" }, pi: { mode: "ok" } });
  const res = await runCompanion(["council", "--scope", "staged", "--json"], env, r);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.equal(out.diff, "", "nothing staged -> empty diff");
  assert.equal(out.findings.length, 0);
});

test("commit scope reviews a specific commit's diff via --base <sha>", async () => {
  const r = makeRepo();
  fs.writeFileSync(path.join(r, "app.js"), "const x = 1;\n// COMMIT_TWO_MARKER\n");
  execFileSync("git", ["add", "-A"], { cwd: r, stdio: "ignore" });
  execFileSync("git", ["commit", "-q", "-m", "second"], { cwd: r, stdio: "ignore" });
  const sha = gitIn(r, ["rev-parse", "HEAD"]);
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--scope", "commit", "--base", sha, "--json"], env, r);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.match(out.diff, /COMMIT_TWO_MARKER/, "the commit's diff is reviewed");
  assert.ok(out.findings.some((f) => f.engine === "grok"), "pipeline ran on the commit diff");
});

test("commit scope defaults to HEAD when no --base is given", async () => {
  const r = makeRepo();
  fs.writeFileSync(path.join(r, "app.js"), "const x = 1;\n// HEAD_COMMIT_MARKER\n");
  execFileSync("git", ["add", "-A"], { cwd: r, stdio: "ignore" });
  execFileSync("git", ["commit", "-q", "-m", "head"], { cwd: r, stdio: "ignore" });
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--scope", "commit", "--json"], env, r);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.match(out.diff, /HEAD_COMMIT_MARKER/);
});

test("commit scope with an unknown ref yields an empty review (graceful)", async () => {
  const r = makeRepo();
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "ok" }, pi: { mode: "ok" } });
  const res = await runCompanion(["council", "--scope", "commit", "--base", "deadbeefdeadbeef", "--json"], env, r);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.equal(out.diff, "", "unknown ref -> empty diff");
  assert.equal(out.findings.length, 0);
});

test("grok-review human render is titled and omits the [engines] consensus tag", async () => {
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "ok" }, pi: { mode: "ok" } });
  const res = await runCompanion(["grok-review"], env);
  assert.equal(res.code, 0, res.stderr);
  assert.match(res.stdout, /# Grok Review/);
  assert.ok(!res.stdout.includes("[grok]"), "single mode omits the engine tag");
});

// ---------- error paths (input validation) + setup diagnostic ----------

test("council-brief without --brief-file errors out", async () => {
  const res = await runCompanion(["council-brief", "--json"], baseEnv({}));
  assert.notEqual(res.code, 0, "missing --brief-file should fail");
  assert.match(res.stderr, /requires --brief-file/);
});

test("council-brief with a nonexistent brief file errors out", async () => {
  const res = await runCompanion(["council-brief", "--brief-file", "/no/such/council-brief.md", "--json"], baseEnv({}));
  assert.notEqual(res.code, 0);
  assert.match(res.stderr, /brief file not found/);
});

test("council-brief with an empty brief file errors out", async () => {
  const f = path.join(mkdtemp("council-brief-"), "empty.md");
  fs.writeFileSync(f, "   \n"); // whitespace-only -> trims to empty
  const res = await runCompanion(["council-brief", "--brief-file", f, "--json"], baseEnv({}));
  assert.notEqual(res.code, 0);
  assert.match(res.stderr, /brief file is empty/);
});

test("an unknown subcommand prints usage and exits non-zero", async () => {
  const res = await runCompanion(["bogus-subcommand"], baseEnv({}));
  assert.notEqual(res.code, 0);
  assert.match(res.stderr, /usage: council-companion/);
});

test("setup reports installed engines and the default active roster", async () => {
  const res = await runCompanion(["setup"], baseEnv({}));
  assert.equal(res.code, 0, res.stderr);
  assert.match(res.stdout, /Grok.*installed/);
  assert.match(res.stdout, /Active roster \(defaults\): grok, codex, glm/);
});

test("setup reflects COUNCIL_ENGINES in the active roster", async () => {
  const res = await runCompanion(["setup"], baseEnv({}, { COUNCIL_ENGINES: "grok, codex" }));
  assert.equal(res.code, 0, res.stderr);
  assert.match(res.stdout, /Active roster \(COUNCIL_ENGINES\): grok, codex/);
});

// ---------- capability: --scope file (review a diff read from a file) ----------

test("file scope reviews a diff read from a file (--scope file --base <path>)", async () => {
  const f = path.join(mkdtemp("council-diff-"), "pr.diff");
  fs.writeFileSync(f, "diff --git a/x.js b/x.js\n--- a/x.js\n+++ b/x.js\n@@ -1 +1,2 @@\n const x = 1;\n+// FILE_DIFF_MARKER\n");
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--scope", "file", "--base", f, "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.match(out.diff, /FILE_DIFF_MARKER/, "the file's contents are reviewed");
  assert.ok(out.findings.some((x) => x.engine === "grok"), "pipeline ran on the file diff");
});

test("file scope works outside a git repository", async () => {
  const dir = mkdtemp("council-nonrepo-");
  const f = path.join(dir, "patch.diff");
  fs.writeFileSync(f, "diff --git a/y.js b/y.js\n+// STANDALONE_PATCH\n");
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--scope", "file", "--base", f, "--json"], env, dir);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  assert.match(out.diff, /STANDALONE_PATCH/, "reviews a file diff with no git repo present");
});

test("file scope without --base errors out", async () => {
  const res = await runCompanion(["council", "--scope", "file", "--json"], baseEnv({}));
  assert.notEqual(res.code, 0);
  assert.match(res.stderr, /requires --base/);
});

test("file scope with a nonexistent diff file errors out", async () => {
  const res = await runCompanion(["council", "--scope", "file", "--base", "/no/such/patch.diff", "--json"], baseEnv({}));
  assert.notEqual(res.code, 0);
  assert.match(res.stderr, /diff file not found/);
});

test("file scope rejects a non-regular file (no hang on fifo/device)", async () => {
  // A directory hits the same isFile() guard that rejects fifos and /dev/zero,
  // where readFileSync would otherwise hang (fifo) or OOM (/dev/zero).
  const dir = mkdtemp("council-notfile-");
  const res = await runCompanion(["council", "--scope", "file", "--base", dir, "--json"], baseEnv({}));
  assert.notEqual(res.code, 0);
  assert.match(res.stderr, /must be a regular file/);
});

test("file scope rejects an oversized diff file (size cap)", async () => {
  const f = path.join(mkdtemp("council-big-"), "big.diff");
  fs.writeFileSync(f, "x".repeat(500));
  const res = await runCompanion(["council", "--scope", "file", "--base", f, "--json"], baseEnv({}, { COUNCIL_MAX_OUTPUT_BYTES: "100" }));
  assert.notEqual(res.code, 0);
  assert.match(res.stderr, /too large/);
});

test("an unknown --scope value is rejected with a clear error (not a silent branch review)", async () => {
  const res = await runCompanion(["council", "--scope", "stage", "--json"], baseEnv({})); // typo for "staged"
  assert.notEqual(res.code, 0);
  assert.match(res.stderr, /unknown --scope/);
  assert.match(res.stderr, /staged/, "lists the valid scopes so the typo is obvious");
});

// ---------- quality: per-finding confidence is plumbed to the chair (--json) ----------

test("council --json: findings carry the per-engine confidence (chair + validator can see it)", async () => {
  // R_GROK's finding has confidence 0.8; it must survive into the chair-bound JSON.
  const env = baseEnv({ grok: { mode: "ok", review: R_GROK }, codex: { mode: "error" }, pi: { mode: "error" } });
  const res = await runCompanion(["council", "--json"], env);
  assert.equal(res.code, 0, res.stderr);
  const out = JSON.parse(res.stdout);
  const grokFinding = out.findings.find((f) => f.engine === "grok");
  assert.ok(grokFinding, "grok finding present");
  assert.equal(grokFinding.confidence, 0.8, "confidence preserved in the chair-bound --json (was previously dropped)");
});
