#!/usr/bin/env node
// council — multi-model adversarial code review with graceful degradation.
//
// Subcommands:
//   grok-review [--base <ref>] [--scope auto|working-tree|branch] [focus ...]
//   council     [--base <ref>] [--scope auto|working-tree|branch] [focus ...]
//   setup
//
// Each engine reviews the SAME diff cold against the SAME prompt + schema, in
// parallel. An engine that errors (missing binary, exhausted quota, timeout) is
// skipped with a note; surviving engines still produce a merged review.

import { spawn, execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const ROOT_DIR = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const SCHEMA_PATH = path.join(ROOT_DIR, "schemas", "review-output.schema.json");
const PROMPT_PATH = path.join(ROOT_DIR, "prompts", "adversarial-review.md");
const BRIEF_PROMPT_PATH = path.join(ROOT_DIR, "prompts", "council-brief.md");
const SCHEMA_TEXT = fs.readFileSync(SCHEMA_PATH, "utf8");
const PROMPT_TEMPLATE = fs.readFileSync(PROMPT_PATH, "utf8");
const BRIEF_TEMPLATE = fs.readFileSync(BRIEF_PROMPT_PATH, "utf8");

const SEVERITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3 };
const ENGINE_TIMEOUT_MS = Number(process.env.COUNCIL_TIMEOUT_MS) || 300000;
// GLM rides pi; point pi at OpenRouter (you already have an OpenRouter key) to enable it.
const GLM_MODEL = process.env.COUNCIL_GLM_MODEL || "openrouter/z-ai/glm-5.2";

const ENGINES = [
  { id: "grok", label: "Grok", bin: "grok", enabled: true, run: runGrok },
  { id: "codex", label: "Codex", bin: "codex", enabled: true, run: runCodex },
  { id: "glm", label: "GLM (via pi)", bin: "pi", enabled: true, run: runGlm },
];

// ---------- helpers ----------
function exec(cmd, args, { timeoutMs = ENGINE_TIMEOUT_MS } = {}) {
  return new Promise((resolve) => {
    let child;
    try {
      child = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    } catch (e) {
      resolve({ code: -1, out: "", err: String(e), killed: false });
      return;
    }
    let out = "";
    let err = "";
    let killed = false;
    const timer = setTimeout(() => {
      killed = true;
      child.kill("SIGKILL");
    }, timeoutMs);
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("error", (e) => {
      clearTimeout(timer);
      resolve({ code: -1, out, err: `${err}${e}`, killed });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({ code, out, err, killed });
    });
  });
}

function git(args, cwd) {
  try {
    return execFileSync("git", args, { cwd, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  } catch (e) {
    return e.stdout ? String(e.stdout) : "";
  }
}

function firstLine(s) {
  return (
    String(s ?? "")
      .split(/\r?\n/)
      .map((x) => x.trim())
      .find(Boolean) || ""
  );
}

function stripFences(s) {
  const t = String(s ?? "").trim();
  const m = t.match(/```(?:json)?\s*([\s\S]*?)```/i);
  return (m ? m[1] : t).trim();
}

function extractJson(text) {
  const t = stripFences(text);
  try {
    return JSON.parse(t);
  } catch {
    /* fall through */
  }
  const start = t.indexOf("{");
  const end = t.lastIndexOf("}");
  if (start >= 0 && end > start) {
    try {
      return JSON.parse(t.slice(start, end + 1));
    } catch {
      /* fall through */
    }
  }
  throw new Error("could not parse JSON from model output");
}

function normSeverity(sev) {
  const s = String(sev ?? "").toLowerCase().trim();
  if (s in SEVERITY_ORDER) return s;
  const map = {
    error: "high",
    blocker: "critical",
    severe: "critical",
    warn: "medium",
    warning: "medium",
    moderate: "medium",
    major: "high",
    minor: "low",
    info: "low",
    note: "low",
    nit: "low",
  };
  return map[s] ?? "medium";
}

function normReview(raw) {
  const r = raw && typeof raw === "object" ? raw : {};
  const findings = Array.isArray(r.findings)
    ? r.findings.map((f) => ({
        severity: normSeverity(f && f.severity),
        title: String((f && (f.title || f.body)) || "Finding").trim(),
        body: String((f && f.body) || "").trim(),
        file: String((f && f.file) || "?").trim(),
        line_start: Number.isFinite(f && f.line_start) ? f.line_start : null,
        line_end: Number.isFinite(f && f.line_end) ? f.line_end : null,
        confidence: typeof (f && f.confidence) === "number" ? f.confidence : null,
        recommendation: String((f && f.recommendation) || "").trim(),
      }))
    : [];
  const verdict = ["approve", "needs-attention"].includes(r.verdict)
    ? r.verdict
    : findings.length
      ? "needs-attention"
      : "approve";
  return {
    verdict,
    summary: String(r.summary || "").trim(),
    findings,
    next_steps: Array.isArray(r.next_steps) ? r.next_steps.map((x) => String(x)) : [],
  };
}

function openEnginePrompt(basePrompt) {
  return `${basePrompt}\n\n=== REQUIRED OUTPUT ===\nReturn ONLY a single JSON object — no prose, no markdown fences — matching this JSON Schema. The "severity" field MUST be exactly one of: critical, high, medium, low.\n\n${SCHEMA_TEXT}\n`;
}

// ---------- engines ----------
async function runGrok(basePrompt, { json = true } = {}) {
  // Agentic but reliable. `--yolo` auto-approves tool calls so the agent does not
  // stall on an approval prompt in headless mode — that stall was the cause of the
  // empty-output flakiness (grok's own docs require --yolo for unattended runs).
  // The read-only `--tools` allowlist keeps that auto-approval safe: the agent can
  // read/grep/list to investigate the change, but cannot edit, run shell, or fetch.
  // json=false → open-brief mode: send the prompt as-is and return the raw take.
  const r = await exec("grok", [
    "-p",
    json ? openEnginePrompt(basePrompt) : basePrompt,
    "--output-format",
    "json",
    "--yolo",
    "--tools",
    "read_file,grep,list_dir",
  ]);
  if (process.env.COUNCIL_DEBUG) {
    try {
      fs.writeFileSync("/tmp/grok-raw-out.txt", r.out);
      fs.writeFileSync("/tmp/grok-raw-err.txt", r.err);
    } catch {
      /* ignore */
    }
  }
  if (r.killed) throw new Error("timed out");
  let env = null;
  try {
    env = extractJson(r.out);
  } catch {
    /* not a JSON envelope; fall back to raw stdout below */
  }
  if (env && env.type === "error") throw new Error(env.message || "grok reported an error");
  const text = env && typeof env.text === "string" ? env.text : env ? JSON.stringify(env) : r.out;
  if (!text.trim()) throw new Error(firstLine(r.err) || "empty output");
  return json ? normReview(extractJson(text)) : text.trim();
}

async function runCodex(basePrompt, { json = true } = {}) {
  // `-o` is codex's output-last-message file. In review mode we pair it with
  // `--output-schema` to get a clean JSON object; in open-brief mode we drop the
  // schema and the file holds the model's raw prose take.
  const ext = json ? "json" : "txt";
  const outFile = path.join(os.tmpdir(), `council-codex-${process.pid}-${Date.now()}.${ext}`);
  const args = json
    ? ["exec", "-s", "read-only", "--output-schema", SCHEMA_PATH, "-o", outFile, basePrompt]
    : ["exec", "-s", "read-only", "-o", outFile, basePrompt];
  try {
    const r = await exec("codex", args);
    const blob = `${r.out}\n${r.err}`;
    if (/usage limit/i.test(blob)) throw new Error("OpenAI usage limit reached");
    if (r.killed) throw new Error("timed out");
    let txt = fs.existsSync(outFile) ? fs.readFileSync(outFile, "utf8").trim() : "";
    if (!txt && !json) txt = r.out.trim(); // fall back to stdout for prose
    if (!txt) throw new Error(firstLine(r.err || r.out) || `exited ${r.code}`);
    return json ? normReview(extractJson(txt)) : txt;
  } finally {
    try {
      fs.rmSync(outFile, { force: true });
    } catch {
      /* ignore */
    }
  }
}

// pi --mode json emits JSONL events; the review lands in the final assistant
// message's text (usually inside a ```json fence). The read-only --tools allowlist
// keeps it agentic (reads/greps the repo) but unable to edit or run shell. pi has
// no permission popups, so there is no headless approval stall to work around.
async function runGlm(basePrompt, { json = true } = {}) {
  const r = await exec("pi", [
    "--model",
    GLM_MODEL,
    "--mode",
    "json",
    "--tools",
    "read,grep,find,ls",
    "-p",
    json ? openEnginePrompt(basePrompt) : basePrompt,
  ]);
  if (r.killed) throw new Error("timed out");
  const text = piAssistantText(r.out);
  if (!text) throw new Error(firstLine(r.err) || "no assistant output from pi");
  return json ? normReview(extractJson(text)) : text.trim();
}

function piAssistantText(stdout) {
  let last = "";
  for (const line of stdout.split(/\r?\n/)) {
    if (!line.trim()) continue;
    let ev;
    try {
      ev = JSON.parse(line);
    } catch {
      continue;
    }
    if (ev && ev.type === "message_end") {
      const content = (ev.message && ev.message.content) || ev.content || [];
      if (Array.isArray(content)) {
        const text = content
          .filter((c) => c && c.type === "text" && typeof c.text === "string")
          .map((c) => c.text)
          .join("\n")
          .trim();
        if (text) last = text;
      }
    }
  }
  return last;
}

// ---------- diff collection ----------
function collectTarget(cwd, { base, scope }) {
  if (git(["rev-parse", "--is-inside-work-tree"], cwd).trim() !== "true") {
    throw new Error("not inside a git repository");
  }
  let mode = scope || "auto";
  const status = git(["status", "--porcelain"], cwd).trim();
  if (mode === "auto") mode = status ? "working-tree" : "branch";

  if (mode === "working-tree") {
    const diff = git(["diff", "HEAD"], cwd);
    const untracked = git(["ls-files", "--others", "--exclude-standard"], cwd).trim();
    const extra = untracked ? `\n\n# Untracked files (not shown in diff):\n${untracked}` : "";
    return { label: "working tree", diff: `${diff}${extra}`.trim() };
  }
  const ref = base || "main";
  return { label: `branch vs ${ref}`, diff: git(["diff", `${ref}...HEAD`], cwd).trim() };
}

// ---------- orchestration ----------
function interpolate(tpl, vars) {
  return tpl.replace(/\{\{(\w+)\}\}/g, (_, k) => (k in vars ? String(vars[k]) : ""));
}

function buildPrompt(target, focus, diff) {
  return interpolate(PROMPT_TEMPLATE, {
    TARGET_LABEL: target,
    USER_FOCUS: focus || "No extra focus provided.",
    REVIEW_COLLECTION_GUIDANCE: "Report each material finding as a structured entry per the schema.",
    REVIEW_INPUT: diff,
  });
}

function buildBriefPrompt(brief) {
  return interpolate(BRIEF_TEMPLATE, { BRIEF: brief });
}

// Open council: fan a free-form brief out to each engine for an independent prose
// take (no schema — open-ended analysis doesn't fit a findings shape). Each take is
// captured raw; the synthesis workflow's chair reconciles them.
async function counselWith(engineIds, brief) {
  const prompt = buildBriefPrompt(brief);
  const engines = ENGINES.filter((e) => engineIds.includes(e.id));
  const takes = [];
  for (const e of engines) {
    const t0 = Date.now();
    try {
      const text = await e.run(prompt, { json: false });
      if (!text || !String(text).trim()) throw new Error("empty take");
      takes.push({ id: e.id, label: e.label, ok: true, text: String(text).trim(), ms: Date.now() - t0 });
    } catch (err) {
      takes.push({ id: e.id, label: e.label, ok: false, error: (err && err.message) || String(err), ms: Date.now() - t0 });
    }
  }
  return takes;
}

function renderTakes(takes) {
  const out = ["# Council — open brief", ""];
  for (const t of takes) {
    out.push(
      t.ok
        ? `- ✅ ${t.label} (${(t.ms / 1000).toFixed(1)}s)`
        : `- ⚠️  ${t.label} skipped — ${t.error} (${(t.ms / 1000).toFixed(1)}s)`
    );
  }
  out.push("");
  const ok = takes.filter((t) => t.ok);
  if (!ok.length) {
    out.push("**No engine produced a take.** All configured members are unavailable (see above).");
    return out.join("\n");
  }
  for (const t of ok) out.push(`## ${t.label}`, "", t.text, "");
  return out.join("\n");
}

async function reviewWith(engineIds, { cwd, base, scope, focus }) {
  const target = collectTarget(cwd, { base, scope });
  if (!target.diff) return { target, empty: true, results: [] };
  const basePrompt = buildPrompt(target.label, focus, target.diff);
  const engines = ENGINES.filter((e) => engineIds.includes(e.id));
  // Engines run sequentially in v1 (simple + verified). Parallelizing is a safe
  // future optimization once there's a second live engine to test concurrency
  // against. NOTE: the grok CLI intermittently returns empty stdout on exit 0
  // (worse under rapid repeated calls) — that's handled as a graceful skip, not
  // a council bug.
  const results = [];
  for (const e of engines) {
    const t0 = Date.now();
    try {
      const review = await e.run(basePrompt);
      results.push({ id: e.id, label: e.label, ok: true, review, ms: Date.now() - t0 });
    } catch (err) {
      results.push({ id: e.id, label: e.label, ok: false, error: (err && err.message) || String(err), ms: Date.now() - t0 });
    }
  }
  return { target, results };
}

function merge(results) {
  const ok = results.filter((r) => r.ok);
  const verdict = ok.some((r) => r.review.verdict === "needs-attention")
    ? "needs-attention"
    : ok.length
      ? "approve"
      : "unknown";
  const map = new Map();
  for (const r of ok) {
    for (const f of r.review.findings) {
      const key = `${f.file}|${f.title.toLowerCase().replace(/\s+/g, " ").slice(0, 50)}`;
      if (!map.has(key)) {
        map.set(key, { ...f, engines: [r.id] });
      } else {
        const e = map.get(key);
        if (!e.engines.includes(r.id)) e.engines.push(r.id);
        if (SEVERITY_ORDER[f.severity] < SEVERITY_ORDER[e.severity]) e.severity = f.severity;
      }
    }
  }
  const findings = [...map.values()].sort(
    (a, b) => SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity] || (b.confidence || 0) - (a.confidence || 0)
  );
  return {
    verdict,
    findings,
    next: [...new Set(ok.flatMap((r) => r.review.next_steps))],
    summaries: ok.map((r) => ({ label: r.label, summary: r.review.summary })),
  };
}

function render(data, { single }) {
  const { target, empty, results } = data;
  const out = [`# ${single ? "Grok Review" : "Council Review"} — ${target.label}`, ""];
  if (empty) {
    out.push("Nothing to review — the target diff is empty.");
    return out.join("\n");
  }
  for (const r of results) {
    out.push(
      r.ok
        ? `- ✅ ${r.label} (${(r.ms / 1000).toFixed(1)}s)`
        : `- ⚠️  ${r.label} skipped — ${r.error} (${(r.ms / 1000).toFixed(1)}s)`
    );
  }
  out.push("");
  const ok = results.filter((r) => r.ok);
  if (!ok.length) {
    out.push("**No engine produced a review.** All configured reviewers are unavailable (see above).");
    return out.join("\n");
  }
  const m = merge(results);
  out.push(`**Verdict: ${m.verdict.toUpperCase()}**`, "");
  for (const s of m.summaries) if (s.summary) out.push(`- *${s.label}:* ${s.summary}`);
  out.push("");
  if (!m.findings.length) {
    out.push("No material findings.");
  } else {
    out.push(`## Findings (${m.findings.length})`, "");
    for (const f of m.findings) {
      const loc = f.line_start
        ? `${f.file}:${f.line_start}${f.line_end && f.line_end !== f.line_start ? `-${f.line_end}` : ""}`
        : f.file;
      const tag = single ? "" : ` _[${f.engines.join(", ")}]_`;
      const conf = f.confidence != null ? ` (conf ${f.confidence})` : "";
      out.push(`### [${f.severity.toUpperCase()}] ${f.title}${tag}`);
      out.push(`\`${loc}\`${conf}`);
      if (f.body) out.push("", f.body);
      if (f.recommendation) out.push("", `**Fix:** ${f.recommendation}`);
      out.push("");
    }
  }
  if (m.next.length) out.push("## Next steps", ...m.next.map((n) => `- ${n}`));
  return out.join("\n");
}

function parseArgs(argv) {
  const opts = { scope: null, base: null, focus: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--base") opts.base = argv[++i];
    else if (a === "--scope") opts.scope = argv[++i];
    else if (a.startsWith("--base=")) opts.base = a.slice(7);
    else if (a.startsWith("--scope=")) opts.scope = a.slice(8);
    else opts.focus.push(a);
  }
  return opts;
}

function setup() {
  const out = ["# Council — engine status", ""];
  for (const e of ENGINES) {
    let present = false;
    try {
      execFileSync(e.bin, ["--version"], { stdio: "ignore" });
      present = true;
    } catch {
      try {
        execFileSync("which", [e.bin], { stdio: "ignore" });
        present = true;
      } catch {
        /* missing */
      }
    }
    const state = !present ? "not installed" : e.enabled ? "enabled" : "disabled (flip `enabled` in council-companion.mjs)";
    out.push(`- ${e.label} (\`${e.bin}\`): ${present ? "installed" : "MISSING"} — ${state}`);
  }
  out.push(
    "",
    "An engine can be installed + enabled and still skip at review time if its provider quota is exhausted — that is graceful degradation, not a bug."
  );
  process.stdout.write(`${out.join("\n")}\n`);
}

function getFlagValue(argv, name) {
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === name) return argv[i + 1];
    if (argv[i].startsWith(`${name}=`)) return argv[i].slice(name.length + 1);
  }
  return undefined;
}

async function briefMain(rest) {
  const briefFile = getFlagValue(rest, "--brief-file");
  if (!briefFile) throw new Error("council-brief requires --brief-file <path>");
  if (!fs.existsSync(briefFile)) throw new Error(`brief file not found: ${briefFile}`);
  const brief = fs.readFileSync(briefFile, "utf8").trim();
  if (!brief) throw new Error("brief file is empty");
  const engineIds = ENGINES.filter((e) => e.enabled).map((e) => e.id);
  const takes = await counselWith(engineIds, brief);
  if (rest.includes("--json")) {
    process.stdout.write(
      `${JSON.stringify({
        brief,
        repoPath: process.cwd(),
        takes: takes.filter((t) => t.ok).map((t) => ({ engine: t.id, label: t.label, text: t.text, ms: t.ms })),
        skipped: takes.filter((t) => !t.ok).map((t) => ({ id: t.id, error: t.error })),
      })}\n`
    );
  } else {
    process.stdout.write(`${renderTakes(takes)}\n`);
  }
}

async function main() {
  const [sub, ...rest] = process.argv.slice(2);
  if (sub === "setup") {
    setup();
    return;
  }
  if (sub === "council-brief") {
    await briefMain(rest);
    return;
  }
  if (sub !== "council" && sub !== "grok-review") {
    process.stderr.write(
      "usage: council-companion.mjs <council|grok-review|council-brief|setup> [--base <ref>] [--scope <mode>] [focus ...] | council-brief --brief-file <path> [--json]\n"
    );
    process.exitCode = 1;
    return;
  }
  const single = sub === "grok-review";
  const asJson = rest.includes("--json");
  const engineIds = single ? ["grok"] : ENGINES.filter((e) => e.enabled).map((e) => e.id);
  const { base, scope, focus } = parseArgs(rest.filter((a) => a !== "--json"));
  const data = await reviewWith(engineIds, { cwd: process.cwd(), base, scope, focus: focus.join(" ") });
  if (asJson) {
    // Compact shape consumed by the synthesis workflow (flat findings, engine-tagged).
    const flat = {
      diff: data.target.diff,
      repoPath: process.cwd(),
      findings: (data.results || [])
        .filter((r) => r.ok)
        .flatMap((r) =>
          ((r.review && r.review.findings) || []).map((f) => ({
            engine: r.id,
            severity: f.severity,
            title: f.title,
            body: f.body,
            file: f.file,
            line_start: f.line_start,
            line_end: f.line_end,
            recommendation: f.recommendation,
          }))
        ),
      skipped: (data.results || []).filter((r) => !r.ok).map((r) => ({ id: r.id, error: r.error })),
    };
    process.stdout.write(`${JSON.stringify(flat)}\n`);
  } else {
    process.stdout.write(`${render(data, { single })}\n`);
  }
}

main().catch((e) => {
  process.stderr.write(`council: ${e && e.message ? e.message : e}\n`);
  process.exitCode = 1;
});
