export const meta = {
  name: 'council-synthesis',
  description: 'Synthesize multi-model review findings into one report (dedupe with consensus), then validate critical/high findings against the actual code. Findings are passed in via args; the external reviewers run outside this workflow.',
  phases: [
    { title: 'Synthesize', detail: 'dedupe + merge findings with consensus tags' },
    { title: 'Validate', detail: 'verify critical/high findings against the real code' },
  ],
}

const FINDING_PROPS = {
  severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
  title: { type: 'string' },
  body: { type: 'string' },
  file: { type: 'string' },
  line_start: { type: 'integer' },
  line_end: { type: 'integer' },
  confidence: { type: 'number' }, // reviewer's self-rated 0..1 certainty; carried through merge for the validator + ranking
  recommendation: { type: 'string' },
}

const SYNTH_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['verdict', 'summary', 'findings'],
  properties: {
    verdict: { type: 'string', enum: ['approve', 'needs-attention'] },
    summary: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'title', 'body', 'file', 'engines'],
        properties: { ...FINDING_PROPS, engines: { type: 'array', items: { type: 'string' } } },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['status', 'reason'],
  properties: {
    status: { type: 'string', enum: ['confirmed', 'refuted', 'adjusted', 'unconfirmed'] },
    reason: { type: 'string' },
    adjusted_severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
  },
}

// Pass-A (blind audit) output: an independent read of the code region with NO claim
// shown, so the judge in pass B isn't primed to agree (confirmation bias).
const AUDIT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['issues'],
  properties: {
    issues: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['description'],
        properties: { description: { type: 'string' }, evidence: { type: 'string' } },
      },
    },
  },
}

// Council-level confidence in THIS verdict (selective prediction / "trust or
// escalate", arXiv:2407.18370): a heuristic cue — NOT a calibrated guarantee — for
// when to take the verdict at face value vs dig deeper. Low when the call rests on
// thin evidence: fewer than two reviewers (no real council), or a needs-attention
// whose strongest finding is a lone, unvalidated claim. Derived only from signals
// already computed (reviewer count + the top finding's corroboration and validation).
function councilConfidence(verdict, findings, reviewers) {
  if (!reviewers || reviewers.length <= 1) return 'low'
  if (verdict === 'approve') return 'high'
  const top = findings && findings[0] // findings are pre-sorted: [0] is the strongest
  const corroborated = !!(top && top.engines && top.engines.length >= 2)
  const validated = !!(top && (top.validated === 'confirmed' || top.validated === 'adjusted'))
  return corroborated || validated ? 'high' : 'low'
}

// args: { findingsFile: string (companion `council --json`: {diff, repoPath, findings:[{engine,...}]}), repoPath: string }
const findingsFile = (args && args.findingsFile) || ''
const repoPath = (args && args.repoPath) || '.'

// --- Synthesize: ONE agent reads the findings file and dedupes/merges. Reading is
// deterministic; merging is the agent's actual job — so there is no fragile
// verbatim pass-through (the failure mode of a separate "load" agent). ---
phase('Synthesize')
const synth = await agent(
  [
    `Read the JSON file at: ${findingsFile}`,
    'It contains `diff` (the unified diff under review) and `findings` (an array; each has: engine, severity, title, body, file, line_start, line_end, confidence (the reviewer\'s self-rated 0..1 certainty the finding is real), recommendation).',
    '',
    'You are the chair of a multi-model code-review council. Merge findings that describe the SAME underlying issue into ONE entry, and set `engines` to every reviewer (`engine`) that raised it (consensus signal). Reconcile conflicting severities to the best-supported one. Keep the file, lines, the strongest recommendation, and the HIGHEST `confidence` among the reviewers that raised it. Do NOT validate or drop anything yet — only dedupe and consolidate against the diff.',
  ].join('\n'),
  { label: 'synthesize', phase: 'Synthesize', schema: SYNTH_SCHEMA }
)

if (!synth) {
  // The chair agent died (terminal error after retries) and returned null. Do NOT
  // report a misleading clean "approve" — the external reviewers may have raised
  // real findings we simply could not merge. Surface it so the caller re-runs.
  return {
    verdict: 'needs-attention',
    summary: 'Synthesis failed: the chair returned no result, so the reviewer findings could not be reconciled. Re-run, or inspect the raw findings file.',
    reviewers: [],
    findings: [],
    dropped: [],
    confidence: 'low',
  }
}

const merged = (synth && synth.findings) || []
const reviewers = [...new Set(merged.flatMap((f) => (f && f.engines) || []))]
if (!merged.length) {
  return {
    verdict: 'approve',
    summary: (synth && synth.summary) || 'No findings.',
    reviewers,
    findings: [],
    dropped: [],
    confidence: councilConfidence('approve', [], reviewers),
  }
}
const order = { critical: 0, high: 1, medium: 2, low: 3 }
const highSev = merged.filter((f) => f.severity === 'critical' || f.severity === 'high')
const lowSev = merged.filter((f) => f.severity === 'medium' || f.severity === 'low')

// --- Validate: verify each critical/high finding against the real code, in parallel.
// TWO PASSES per finding to defeat confirmation bias (arXiv:2603.18740 — a validator
// shown the claim first is primed to agree). Pass A audits the code region BLIND (no
// claim). Pass B then judges the claim against that independent read. The conservative
// refute-only rule is preserved, so the worst case is "no improvement", never a
// wrongly-dropped real finding. ---
phase('Validate')
const fileNote = (f) =>
  `Use the Read tool on the EXACT absolute path ${repoPath}/${f.file} directly. Do NOT use find / grep / git / ls or the current working directory — the CWD may be a DIFFERENT, unrelated repository and will mislead you into thinking the file is missing.`
const checked = await parallel(
  highSev.map((f) => async () => {
    // Pass A — BLIND independent audit: NO claim shown, so the read isn't anchored.
    const audit = await agent(
      [
        `Audit a region of source code independently. ${fileNote(f)}`,
        `Read the file and examine the code around lines ${f.line_start ?? '?'}-${f.line_end ?? '?'}. Report what — if ANYTHING — is genuinely wrong there. Do NOT assume a problem exists; many regions are perfectly fine, in which case return an empty list. For each issue you actually see, quote the offending line(s) as evidence.`,
      ].join('\n'),
      { label: `audit:${f.file}`, phase: 'Validate', schema: AUDIT_SCHEMA }
    ).catch(() => null)
    // Pass B — JUDGE the claim against the INDEPENDENT audit (only now is the claim revealed).
    const v = await agent(
      [
        `An independent auditor examined ${repoPath}/${f.file} WITHOUT seeing any claim, and reported these issues:`,
        audit ? JSON.stringify(audit.issues || [], null, 2) : '(the independent audit produced no result)',
        '',
        `Now judge THIS finding a code reviewer raised about the same code. You may re-read the file to settle it. ${fileNote(f)}`,
        '',
        'FINDING (JSON):',
        JSON.stringify(f, null, 2),
        '',
        `Decide:`,
        `  - "confirmed": the independent audit corroborates the finding, OR the code plainly exhibits it.`,
        `  - "refuted": the file's actual contents POSITIVELY CONTRADICT the finding. Refute ONLY on positive contradiction, never merely because the audit missed it.`,
        `  - "unconfirmed": the independent audit did NOT surface it and you cannot positively contradict it — keep it, flagged as not independently reproduced.`,
        `  - "adjusted" (with adjusted_severity): real, but the severity is clearly off.`,
        `If you genuinely cannot read the file, do NOT refute and do NOT mark unconfirmed — return "confirmed" (absence of the file is not evidence the finding is wrong).`,
        `The finding's "engines" field is NOT evidence of correctness — independent models frequently agree on the SAME wrong conclusion (correlated errors). Judge against the actual code. "confidence" (0..1) low (<= 0.4) means scrutinize harder, not refute.`,
      ].join('\n'),
      { label: `validate:${f.file}`, phase: 'Validate', schema: VERDICT_SCHEMA }
    ).catch(() => null)
    return { finding: f, v }
  })
)

const keptHigh = []
const dropped = []
for (const r of checked.filter(Boolean)) {
  if (r.v && r.v.status === 'refuted') {
    dropped.push({ ...r.finding, refuted_reason: r.v.reason })
    continue
  }
  const severity = r.v && r.v.status === 'adjusted' && r.v.adjusted_severity ? r.v.adjusted_severity : r.finding.severity
  keptHigh.push({ ...r.finding, severity, validated: r.v ? r.v.status : 'unverified' })
}

// Within a severity band, surface corroborated findings (>=2 reviewers) above
// solo ones — coarse tier only, since effective votes saturate near 2
// (arXiv:2605.29800). Solo findings are kept, just ranked lower (recall-favoring).
// Reviewer confidence breaks remaining ties (now that it's carried through).
const corroboration = (f) => (f.engines && f.engines.length >= 2 ? 1 : 0)
const findings = [...keptHigh, ...lowSev].sort(
  (a, b) =>
    order[a.severity] - order[b.severity] ||
    corroboration(b) - corroboration(a) ||
    (b.confidence || 0) - (a.confidence || 0)
)

const verdict = findings.length ? 'needs-attention' : 'approve'
return {
  verdict,
  summary: (synth && synth.summary) || '',
  reviewers,
  findings,
  dropped,
  confidence: councilConfidence(verdict, findings, reviewers),
}
