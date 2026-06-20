export const meta = {
  name: 'council-synthesis-generic',
  description:
    'Synthesize independent multi-model takes on an open brief (a design, decision, plan, spec, or question) into one consolidated view: consensus, divergences, strongest points, open questions, and a chair recommendation. Takes are passed in via args; the external models run outside this workflow.',
  phases: [{ title: 'Synthesize', detail: 'reconcile the council takes into one view' }],
}

const SYNTH_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['summary', 'recommendation', 'consensus', 'divergences', 'open_questions', 'takes'],
  properties: {
    summary: { type: 'string' },
    recommendation: { type: 'string' },
    consensus: { type: 'array', items: { type: 'string' } },
    divergences: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['point', 'positions'],
        properties: {
          point: { type: 'string' },
          positions: {
            type: 'array',
            items: {
              type: 'object',
              additionalProperties: false,
              required: ['engines', 'stance'],
              properties: {
                engines: { type: 'array', items: { type: 'string' } },
                stance: { type: 'string' },
              },
            },
          },
        },
      },
    },
    strongest_points: { type: 'array', items: { type: 'string' } },
    open_questions: { type: 'array', items: { type: 'string' } },
    takes: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['engine', 'gist'],
        properties: { engine: { type: 'string' }, gist: { type: 'string' } },
      },
    },
  },
}

// args: { takesFile: string (companion `council-brief --json`: {brief, repoPath, takes:[{engine,label,text}]}), repoPath: string }
const takesFile = (args && args.takesFile) || ''
const repoPath = (args && args.repoPath) || '.'

// --- Synthesize: ONE fresh-context chair reads the takes file and reconciles them.
// Reading is deterministic; reconciling is the agent's actual job — same reliable
// pattern as the review synthesis (no fragile verbatim pass-through). The chair did
// NOT write any take, so the synthesis stays neutral and is not anchored on the
// caller's conversation. ---
phase('Synthesize')
const synth = await agent(
  [
    `Read the JSON file at: ${takesFile}`,
    "It contains `brief` (the question / design / decision put to the council) and `takes` (an array; each has: engine, label, text — one model's independent prose assessment of the brief).",
    `If the brief references code under ${repoPath}, you may Read files there (read-only) to judge which take is better grounded — but your job is synthesis, NOT your own fresh review of the subject.`,
    '',
    'You are the chair of a multi-model advisory council. You did NOT write any of the takes; reconcile them neutrally. Produce:',
    '- summary: one or two sentences capturing the council\'s overall read.',
    "- recommendation: the consolidated call. If the takes converge, state it plainly. If they genuinely diverge, say what it depends on and give your best-judgment lean AS CHAIR (mark it as the chair's call, not unanimous).",
    '- consensus: points most or all takes agree on.',
    '- divergences: substantive disagreements. For each, state the point and the differing positions, attributing each stance to the engine(s) that hold it. This is the most valuable output — surface real disagreement, do not paper over it.',
    '- strongest_points: the most compelling individual arguments raised by ANY single member, even if only one raised it.',
    '- open_questions: what the council could not resolve, or what the brief left underspecified.',
    '- takes: a one-line gist per engine of that member\'s overall position.',
    '',
    'Be faithful to what the members actually argued. Do not invent agreement or disagreement, and do not inject your own opinion as if it were a member\'s take.',
  ].join('\n'),
  { label: 'chair', phase: 'Synthesize', schema: SYNTH_SCHEMA }
)

return (
  synth || {
    summary: 'No takes to synthesize.',
    recommendation: '',
    consensus: [],
    divergences: [],
    strongest_points: [],
    open_questions: [],
    takes: [],
  }
)
