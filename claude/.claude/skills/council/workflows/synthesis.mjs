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
    status: { type: 'string', enum: ['confirmed', 'refuted', 'adjusted'] },
    reason: { type: 'string' },
    adjusted_severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
  },
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
    'It contains `diff` (the unified diff under review) and `findings` (an array; each has: engine, severity, title, body, file, line_start, line_end, recommendation).',
    '',
    'You are the chair of a multi-model code-review council. Merge findings that describe the SAME underlying issue into ONE entry, and set `engines` to every reviewer (`engine`) that raised it (consensus signal). Reconcile conflicting severities to the best-supported one. Keep the file, lines, and the strongest recommendation. Do NOT validate or drop anything yet — only dedupe and consolidate against the diff.',
  ].join('\n'),
  { label: 'synthesize', phase: 'Synthesize', schema: SYNTH_SCHEMA }
)

const merged = (synth && synth.findings) || []
const reviewers = [...new Set(merged.flatMap((f) => (f && f.engines) || []))]
if (!merged.length) {
  return { verdict: 'approve', summary: (synth && synth.summary) || 'No findings.', reviewers, findings: [], dropped: [] }
}
const order = { critical: 0, high: 1, medium: 2, low: 3 }
const highSev = merged.filter((f) => f.severity === 'critical' || f.severity === 'high')
const lowSev = merged.filter((f) => f.severity === 'medium' || f.severity === 'low')

// --- Validate: verify each critical/high finding against the real code, in parallel ---
phase('Validate')
const checked = await parallel(
  highSev.map((f) => () =>
    agent(
      [
        `Verify this code-review finding against the real code. The file is at this EXACT absolute path:`,
        `  ${repoPath}/${f.file}`,
        `Use the Read tool on that absolute path directly. Do NOT use find / grep / git / ls or the current working directory to locate the file — the CWD may be a different, unrelated repository and will mislead you into thinking the file is missing. The file you need is the absolute path above.`,
        `Judge whether the finding is real and accurately describes that file's current code.`,
        `Be conservative about dropping: return "refuted" ONLY if the file's actual contents positively contradict the finding. If you genuinely cannot read the file at that absolute path, do NOT refute — return "confirmed" (trust the reviewers; absence of the file is not evidence the finding is wrong). Return "adjusted" (with adjusted_severity) if real but the severity is clearly off; otherwise "confirmed".`,
        '',
        'FINDING (JSON):',
        JSON.stringify(f, null, 2),
      ].join('\n'),
      { label: `validate:${f.file}`, phase: 'Validate', schema: VERDICT_SCHEMA }
    )
      .then((v) => ({ finding: f, v }))
      .catch(() => ({ finding: f, v: null }))
  )
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

const findings = [...keptHigh, ...lowSev].sort((a, b) => order[a.severity] - order[b.severity])

return {
  verdict: findings.length ? 'needs-attention' : 'approve',
  summary: (synth && synth.summary) || '',
  reviewers,
  findings,
  dropped,
}
