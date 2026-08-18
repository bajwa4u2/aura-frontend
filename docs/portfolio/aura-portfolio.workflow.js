export const meta = {
  name: 'aura-portfolio',
  description: 'Reconstruct Aura\'s implementation portfolio from the F-register, WG register and the C0–C11 roadmap',
  whenToUse: 'Portfolio-control boundary: when the F-register has grown beyond linear management and the next objective is deciding which SYSTEMS remain to reconstruct, not which bug to fix next.',
  phases: [
    { title: 'Evidence', detail: 'Reconstruct register, doctrine, roadmap and system state into durable artifacts — once' },
    { title: 'Analysis', detail: 'Root-system, dependency/boundary and product/validation analysis over the artifacts' },
    { title: 'Reconcile', detail: 'Map onto C0–C11, then attack the result adversarially' },
    { title: 'Synthesis', detail: 'Emit founder + engineering portfolios with a full ownership ledger' },
  ],
}

// ─────────────────────────────────────────────────────────────────────────────
// AURA DYNAMIC RECONSTRUCTION WORKFLOW
//
// DESIGN NOTES THAT ARE LOAD-BEARING — read before editing:
//
//  1. The script has NO filesystem access. It cannot write artifacts. Every
//     agent writes its own artifact with its Write tool and ALSO returns the
//     object. That is why each prompt carries an explicit write instruction.
//
//  2. Date.now() / Math.random() / new Date() THROW here. `runLabel` and
//     `today` arrive through `args`.
//
//  3. Concurrency: the platform cap is min(16, CPUs-2) = 10 on this machine.
//     The founder's operating constraint is <= 3 heavyweight agents. The
//     platform will NOT enforce that, so every batch below is sized to 3.
//
//  4. Idempotence across sessions: every agent is told to return its existing
//     artifact unchanged if it is already present and valid. That makes the
//     workflow resumable after a laptop restart or a Max quota reset even
//     without resumeFromRunId.
//
//  5. Halt-on-missing-evidence: a partial portfolio that LOOKS complete is the
//     exact failure this workflow exists to prevent. Missing Stage 0 or
//     Stage 1 artifacts abort synthesis.
// ─────────────────────────────────────────────────────────────────────────────

const RUN = (args && args.runLabel) || 'unlabelled'
const TODAY = (args && args.today) || 'unknown-date'
const COMPARE = (args && args.compare) || null
const ROOT = `aura_final/docs/portfolio/run/${RUN}`

// Shared preamble. Every agent gets this verbatim.
const CONTRACT = `
YOU ARE AN ANALYSIS AGENT IN A GOVERNED PORTFOLIO WORKFLOW. Run label: ${RUN}. Date: ${TODAY}.

ABSOLUTELY PROHIBITED:
  - Writing or modifying ANY file outside ${ROOT}/
  - Implementing anything, or changing product code
  - Changing frozen founder doctrine, or resolving a founder decision
  - Deleting, merging away, or silently renumbering any finding
  - Mutating production data; running the media reaper
  - Touching Meetings, Realtime, or Live in any way
  - Presenting uncertainty as fact

MANDATORY DISAMBIGUATION — this has already caused confident errors:
  "C0..C11" are FRONTEND RECONSTRUCTION CHAPTERS (C0 Cross-Cutting Foundations,
  C1 Acting Context, C2 Identity/Presence/Profile, C3 Navigation/IA, C4 Attention,
  C5 Composition/Intake, C6 Realtime Presentation, C7 Threads/Spaces/Correspondence,
  C8 Institution Room, C9 Cross-Platform Completion, C10 Live (cross-repository),
  C11 Item 17 / Release Gate).
  "§12 C1/C2/C3..." are RICH CONTENT IMPLEMENTATION STAGES (C1 Content Truth,
  C2 Reference/Retention Index, ...). THESE ARE DIFFERENT AXES. Never equate them.
  §12 C2 has nothing to do with roadmap C2 — Identity, Presence & Profile.

EVIDENCE DISCIPLINE:
  - Every claim carries provenance: file path + anchor, or transcript file + line.
  - Anything you cannot evidence goes in "openQuestions". Do not assert it.
  - Preserve certification states EXACTLY as recorded. You may not promote a
    finding's state. Infrastructure existing is NOT an obligation being satisfied.

IDEMPOTENCE:
  Before doing any work, check whether your output artifact already exists and is
  valid JSON. If so, return its contents unchanged and do nothing else.

STOP CONDITION:
  If a required input artifact is missing or malformed, STOP. Return
  { "status": "BLOCKED", "reason": "..." }. Do not improvise inputs.
`

// ── Schemas ─────────────────────────────────────────────────────────────────

const ARTIFACT = (extra) => ({
  type: 'object',
  additionalProperties: true,
  required: ['status', 'artifactPath'],
  properties: Object.assign(
    {
      status: { type: 'string', enum: ['OK', 'BLOCKED', 'PARTIAL'] },
      artifactPath: { type: 'string' },
      openQuestions: { type: 'array', items: { type: 'string' } },
      contradictions: { type: 'array', items: { type: 'string' } },
    },
    extra || {},
  ),
})

const REGISTER_SCHEMA = ARTIFACT({
  findingCount: { type: 'integer' },
  wgCount: { type: 'integer' },
  idRangeLow: { type: 'string' },
  idRangeHigh: { type: 'string' },
  missingIds: { type: 'array', items: { type: 'string' } },
  weakEvidenceIds: { type: 'array', items: { type: 'string' } },
  duplicateIds: { type: 'array', items: { type: 'string' } },
})

const COUNTED = ARTIFACT({ itemsCovered: { type: 'integer' } })

const PORTFOLIO_SCHEMA = ARTIFACT({
  chapterCount: { type: 'integer' },
  canonicallyOwnedFindings: { type: 'integer' },
  chapters: {
    type: 'array',
    items: {
      type: 'object',
      additionalProperties: true,
      required: ['id', 'name', 'canonicalFindings'],
      properties: {
        id: { type: 'string' },
        name: { type: 'string' },
        purpose: { type: 'string' },
        rootDeficiency: { type: 'string' },
        cRelationship: { type: 'array', items: { type: 'string' } },
        canonicalFindings: { type: 'array', items: { type: 'string' } },
        crossReferencedFindings: { type: 'array', items: { type: 'string' } },
        wgAbsorbed: { type: 'array', items: { type: 'string' } },
        maturity: { type: 'string' },
        dependsOn: { type: 'array', items: { type: 'string' } },
        protectedBoundaries: { type: 'array', items: { type: 'string' } },
        implementationRisk: { type: 'string' },
        validationTopology: { type: 'array', items: { type: 'string' } },
        externalDependencies: { type: 'array', items: { type: 'string' } },
        founderDecisions: { type: 'array', items: { type: 'string' } },
        productImpact: { type: 'string' },
        competitiveSignificance: { type: 'string' },
        sequencePosition: { type: 'integer' },
        completionDefinition: { type: 'string' },
      },
    },
  },
})

// ── STAGE 0 — canonical evidence, gathered ONCE ─────────────────────────────

phase('Evidence')
log(`Stage 0 — building canonical evidence package at ${ROOT}/00-evidence/`)

const evidence = await parallel([
  () =>
    agent(
      `${CONTRACT}

TASK — RECONSTRUCT THE CANONICAL REGISTERS.

CRITICAL CONTEXT: there is NO canonical F-register file in any repository. A prior
sweep found only ~27 distinct F-ids in governed markdown. The register survives
almost entirely inside Claude session transcripts at:
  C:/Users/muham/.claude/projects/C--Users-muham-flutter-projects/*.jsonl  (~745 MB, 22 files)

A prior read-only sweep established, and you must VERIFY rather than trust:
  - F-ids F001..F143 appear, with exactly one gap: F097 (zero occurrences anywhere)
  - tokens above F143 (F214, F332, F990, ...) are base64 FALSE POSITIVES
  - ~42 F-ids appear only once or twice => weak evidence
  - WG ids approximately WG001..WG018

For EVERY finding recover: id, title/claim, the system it concerns, current state
(OPEN / IMPLEMENTED-NOT-CERTIFIED / CLOSED / RETIRED / SUPERSEDED / BLOCKED / C4-OWNED),
originating chapter or investigation, and provenance (transcript file + line, or doc path).

Do the same for WG items.

Prefer grep/ripgrep over reading whole transcripts — they are very large.

WRITE:
  ${ROOT}/00-evidence/findings.jsonl            one JSON object per line
  ${ROOT}/00-evidence/wg.jsonl
  ${ROOT}/00-evidence/register-anomalies.json   missing / duplicate / malformed /
                                                contradictory / weak-evidence
NEVER repair the register. Report anomalies; do not fix them.
This output is PROPOSED, not canonical, until the founder ratifies it. Say so in the file.`,
      { label: 'S0-A register', phase: 'Evidence', schema: REGISTER_SCHEMA, effort: 'high' },
    ),

  () =>
    agent(
      `${CONTRACT}

TASK — EXTRACT DOCTRINE, ROADMAP AND PROTECTED BOUNDARIES.

Canonical roadmap: aura_final/docs/frontend-discovery/FINAL_FRONTEND_RECONSTRUCTION_ROADMAP.md
It defines C0..C11 (TWELVE chapters — C9 Cross-Platform Completion, C10 Live
cross-repository, and C11 Item 17 / Release Gate are real and must not be dropped).

Also read: docs/frontend-discovery/*_FROZEN.md, FOUNDER_DECISION_REGISTER.md,
DECISIONS.md, CURRENT_STATE.md, and the Rich Content §12 contract plus its
Amendment 1 (2026-08-18) including ruling D-5.1.

For each C-chapter capture: intended scope, frozen rulings, current state,
explicit exclusions, and the certification layer it belongs to.
Capture every frozen doctrine and every protected boundary (Meetings, Realtime,
Live, C4-owned findings, identity, storage) with its exact prohibition.

WRITE:
  ${ROOT}/00-evidence/roadmap.json
  ${ROOT}/00-evidence/doctrines.json
  ${ROOT}/00-evidence/boundaries.json`,
      { label: 'S0-B doctrine', phase: 'Evidence', schema: COUNTED, agentType: 'Explore', effort: 'high' },
    ),

  () =>
    agent(
      `${CONTRACT}

TASK — SYSTEM MAP, CHAPTER STATE AND VALIDATION DEBT.

Map the repositories and runtime systems: aura-backend (NestJS + Prisma + Railway
Postgres + R2), aura_final (Flutter client), and any other repo that participates
in Aura's reconstruction.

Determine, with evidence: which implementation chapters are complete, which are
active or paused, which are certified vs implemented-not-certified, and what
validation debt is outstanding.

Useful sources: docs/CURRENT_STATE.md, HANDOFF.md, NEXT_WORK.md, DECISIONS.md,
aura-backend/capability/*REGISTER*.md, aura-backend/docs/2026-08-18-c2-retention-truth-register.md,
and git log on both repos.

Classify each outstanding validation obligation into exactly one topology:
  static-code | local-automated | single-browser | two-account-two-browser |
  multi-party-realtime | native-device | production-read-only |
  external-infrastructure | founder-experiential

WRITE:
  ${ROOT}/00-evidence/systems.json
  ${ROOT}/00-evidence/chapters-state.json
  ${ROOT}/00-evidence/validation-debt.json`,
      { label: 'S0-C systems', phase: 'Evidence', schema: COUNTED, agentType: 'Explore', effort: 'high' },
    ),
])

const evidenceOk = evidence.filter(Boolean).filter((e) => e && e.status !== 'BLOCKED')
if (evidenceOk.length < 3) {
  log('HALT — canonical evidence incomplete. Refusing to analyse a partial corpus.')
  return {
    status: 'HALTED_AT_EVIDENCE',
    reason: 'One or more Stage 0 agents failed or returned BLOCKED.',
    evidence,
  }
}
log('Stage 0 complete — later stages consume artifacts, not the raw corpus.')

// ── STAGE 1 — three heavy analyses, bounded concurrency ─────────────────────

phase('Analysis')

const READ_ARTIFACTS = `
READ ONLY THESE INPUTS (do not re-derive the project from scratch — that multiplies
cost without multiplying truth):
  ${ROOT}/00-evidence/findings.jsonl
  ${ROOT}/00-evidence/wg.jsonl
  ${ROOT}/00-evidence/roadmap.json
  ${ROOT}/00-evidence/doctrines.json
  ${ROOT}/00-evidence/boundaries.json
  ${ROOT}/00-evidence/systems.json
  ${ROOT}/00-evidence/chapters-state.json
  ${ROOT}/00-evidence/validation-debt.json
`

const analysis = await parallel([
  () =>
    agent(
      `${CONTRACT}${READ_ARTIFACTS}

TASK — ROOT-SYSTEM / DOMAIN ANALYSIS.

For EVERY finding, determine the actual underlying system whose correction would
discharge the obligation the finding represents.

THE TEST — apply it literally:
  "What architectural or system correction would actually resolve this obligation?"

FORBIDDEN groupings: by UI surface, by screen name, by shared vocabulary, by
repository, or by severity. Those produce backlog buckets, not reconstruction systems.

WORKED EXAMPLE OF THE REQUIRED STANDARD — Rich Content did NOT become
"fix F126 / fix F127 / fix F131". It resolved into real systems:
  Content Truth · Reference & Retention Truth · Fail-Closed Ingestion ·
  Governed Delivery · Processing/Derivatives · Rich Acquisition · Rich Presentation
while every individual finding survived as evidence and as a certification obligation.

Propose candidate Implementation Chapters at that altitude. EVERY finding must be
accounted for — including retired, superseded, blocked and C4-owned ones.

WRITE: ${ROOT}/01-analysis/finding-domains.json
Include, per finding: id, proposedChapter, rootSystem, reasoning, provenance.`,
      { label: 'A root-system', phase: 'Analysis', schema: COUNTED, effort: 'high' },
    ),

  () =>
    agent(
      `${CONTRACT}${READ_ARTIFACTS}

TASK — DEPENDENCY, RISK AND PROTECTED-BOUNDARY ANALYSIS.

Determine: prerequisite chains · shared authorities · cross-repository dependencies ·
destructive operations · migration dependencies · authentication, identity and
storage boundaries · realtime boundaries · Meetings protection · C4 ownership ·
Live interactions · production-data dependencies · external infrastructure
dependencies (R2, Railway, stores, push).

You MAY read targeted source files to confirm a dependency. You may NOT change any.

State clearly which candidate chapters can proceed INDEPENDENTLY and which cannot,
and why. Flag anything whose implementation would require touching a protected system.

WRITE: ${ROOT}/01-analysis/dependencies.json`,
      { label: 'B dependencies', phase: 'Analysis', schema: COUNTED, effort: 'high' },
    ),

  () =>
    agent(
      `${CONTRACT}${READ_ARTIFACTS}

TASK — PRODUCT, COMPETITIVE AND VALIDATION ANALYSIS.

FROZEN PRODUCT STANDARD — Aura is not reconstructed merely until it "works". The
released client must be visibly modern, rich, low-friction, coherent, and able to
compete for user attention and institutional adoption against mature communication
and productivity products.

Evaluate every finding and WG opportunity against: user friction · missing modern
interaction · presentation quality · content richness · continuity · responsiveness ·
acquisition/discovery · credibility and trust · institutional usability · public
usability · competitive parity · world-class opportunity.

The frozen rich-interaction standard includes: selection, copy/paste, drag/drop,
text, rich text, images, video, audio, voice messages, video messages, documents,
PDF, DOCX, PPTX, emoji, hydrated previews, original identity/naming/presentation,
and modern low-friction interaction — plus analogous standards in other domains.

WG items are NOT a someday-polish backlog. Reconstruction is the SAFEST time to
absorb them. For each WG item say which chapter should absorb it and why — but keep
it separately traceable by WG id.

Also assign every item exactly one validation topology:
  static-code | local-automated | single-browser | two-account-two-browser |
  multi-party-realtime | native-device | production-read-only |
  external-infrastructure | founder-experiential

WRITE: ${ROOT}/01-analysis/product-validation.json`,
      { label: 'C product', phase: 'Analysis', schema: COUNTED, effort: 'high' },
    ),
])

if (analysis.filter(Boolean).length < 3) {
  log('HALT — analysis incomplete. Refusing to reconcile from partial analysis.')
  return { status: 'HALTED_AT_ANALYSIS', analysis }
}

// ── STAGE 2 — reconciliation, then adversarial attack (sequential) ──────────
//
// D and E are SEQUENTIAL, not concurrent. E's job is to attack the synthesis;
// if it ran alongside D it could not see D's C0..C11 mapping, and a chapter
// quietly dropping a C9/C10/C11 obligation is exactly what E must catch.

phase('Reconcile')

const cMap = await agent(
  `${CONTRACT}${READ_ARTIFACTS}
  ${ROOT}/01-analysis/finding-domains.json
  ${ROOT}/01-analysis/dependencies.json
  ${ROOT}/01-analysis/product-validation.json

TASK — RECONCILE PROPOSED CHAPTERS AGAINST THE C0..C11 RECONSTRUCTION MAP.

C0..C11 remains the RECONSTRUCTION MAP. The F-register remains the EVIDENCE
REGISTER. Neither replaces the other.

For each C-phase determine: what it intended · what has actually been reconstructed ·
what remains · where later findings exposed that the original assumption was
incomplete · where a new implementation chapter SUPERSEDES a simplistic reading of a
C-phase WITHOUT erasing that C-phase's purpose.

Then answer the question that matters most:
  HAS ANY ORIGINAL RECONSTRUCTION OBLIGATION DISAPPEARED FROM CURRENT PLANNING?
Pay particular attention to C9, C10 and C11, which are easy to lose.

WRITE: ${ROOT}/02-reconcile/c-map.json`,
  { label: 'D c-map', phase: 'Reconcile', schema: COUNTED, effort: 'xhigh' },
)

const adversarial = await agent(
  `${CONTRACT}${READ_ARTIFACTS}
  ${ROOT}/01-analysis/*.json
  ${ROOT}/02-reconcile/c-map.json

TASK — ADVERSARIAL REVIEW. YOU ARE NOT HERE TO MAKE THE PORTFOLIO LOOK CLEAN.

Attack the proposed synthesis. Answer EVERY question below explicitly, with a
verdict and cited evidence. A review that returns "no issues found" is treated as
YOUR FAILURE, not as the portfolio being sound.

  1. Are findings grouped because they share WORDS rather than root causes?
  2. Are distinct obligations being silently merged?
  3. Has any F-item disappeared?
  4. Is any OPEN item treated as resolved because infrastructure now exists?
  5. Are implemented-not-certified items mistaken for complete?
  6. Is legacy preserved merely because migration is inconvenient?
  7. Is sequencing driven by engineering convenience rather than product consequence?
  8. Are WG/world-class improvements postponed even though reconstruction is the
     safest time to implement them?
  9. Are protected systems being casually exposed?
 10. Are validation requirements understated?
 11. Are founder decisions being converted into engineering assumptions?
 12. Are broad chapters hiding unresolved findings?
 13. Are all C0..C11 objectives still represented?
 14. Is any chapter so large that it merely recreates the 142-item dump under
     another name?

Disagreement IS evidence. Do not reconcile with the other agents. Do not vote.
Preserve every disagreement with both positions and their evidence.

WRITE: ${ROOT}/02-reconcile/adversarial.json`,
  { label: 'E adversarial', phase: 'Reconcile', schema: COUNTED, effort: 'xhigh' },
)

// ── STAGE 3 — synthesis ─────────────────────────────────────────────────────

phase('Synthesis')

const portfolio = await agent(
  `${CONTRACT}${READ_ARTIFACTS}
  ${ROOT}/01-analysis/*.json
  ${ROOT}/02-reconcile/c-map.json
  ${ROOT}/02-reconcile/adversarial.json
${COMPARE ? `  PREVIOUS PORTFOLIO for delta: aura_final/docs/portfolio/run/${COMPARE}/03-synthesis/portfolio.json` : ''}

TASK — SYNTHESISE THE IMPLEMENTATION PORTFOLIO.

The output is NOT a bug backlog. Target roughly 8-15 coherent Implementation
Chapters — but the ACTUAL number must follow the evidence, not that range.

Each chapter carries: name · governing purpose · root deficiency corrected ·
C0..C11 relationship · canonical F-items owned · cross-referenced F-items ·
WG opportunities absorbed · current maturity · dependencies · protected boundaries ·
implementation risk · validation topology · external dependencies · outstanding
founder decisions · expected user/product impact · competitive significance ·
recommended sequencing · definition of chapter completion.

HARD INVARIANTS — a violation invalidates the run:
  * EVERY finding has EXACTLY ONE canonical owning chapter.
  * Cross-references are 0..N and never substitute for ownership.
  * No finding disappears for being grouped, duplicated, structurally addressed,
    implemented-uncertified, C4-owned, blocked, retired or superseded. Retired and
    superseded findings reconcile HISTORICALLY, with a state — never by omission.
  * Certification states are copied verbatim from Stage 0. You may not promote one.
  * Every founder decision stays a decision.
  * Where Agent E raised an unresolved disagreement, either resolve it from canonical
    evidence WITH CITED REASONING, or elevate it as a founder decision. Never drop it.

WRITE:
  ${ROOT}/03-synthesis/portfolio.json            machine-readable, full ledger
  ${ROOT}/03-synthesis/founder-portfolio.md      control board; counts not ID lists;
                                                 answers "what next and why"
  ${ROOT}/03-synthesis/engineering-portfolio.md  full traceability; every finding
                                                 visible beneath its canonical chapter`,
  { label: 'F synthesis', phase: 'Synthesis', schema: PORTFOLIO_SCHEMA, effort: 'xhigh' },
)

// Stage 4 (deterministic reconciliation) is intentionally NOT an agent. A model
// asserting "142 == 142" is an assertion; a script computing it is a proof. The
// orchestrator runs verify-portfolio.mjs over findings.jsonl + portfolio.json.

log(`Synthesis complete. Run Stage 4 proof: node verify-portfolio.mjs ${ROOT}`)

return {
  status: 'SYNTHESIS_COMPLETE_PENDING_DETERMINISTIC_PROOF',
  runLabel: RUN,
  root: ROOT,
  evidence,
  analysis,
  cMap,
  adversarial,
  portfolio,
  nextStep: `node aura_final/docs/portfolio/verify-portfolio.mjs ${ROOT}`,
}
