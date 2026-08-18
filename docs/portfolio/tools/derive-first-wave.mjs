#!/usr/bin/env node
// DERIVE-FIRST-WAVE v2
// Re-derives the first executable wave from canonical evidence under the four
// 2026-08-18 founder pre-execution rulings. Stage-5 W1 is NOT assumed correct.
// Deterministic: no clock, no randomness, no network. Read-only over artifacts.
import { readFileSync, writeFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const RUN = resolve(HERE, '../run/stage0-2026-08-18/05-execution')
const rd = (f) => JSON.parse(readFileSync(resolve(RUN, f), 'utf8'))

const chapters = rd('index-chapters.json').chapters
const s5 = rd('s5-execution-architecture.json')
const graph = rd('execution-graph-v2.json')
const byId = Object.fromEntries(chapters.map((c) => [c.id, c]))

// ---------------------------------------------------------------- RULINGS ---
// Ruling-driven overrides on Stage-5 readiness. Each carries its authority.
// A CONFLICTED cell is SPLIT, never cleared; nothing is promoted.
const RULING_OVERRIDES = [
  {
    chapter: 'CH-04',
    dimension: 'constructionReadiness',
    from: 'CONFLICTED',
    to: 'SPLIT_BY_RULING_3',
    founderRuling: 'RULING 3',
    reason:
      'The F006-F010 contradiction is dissolved into two preserved truths, not resolved in either direction. Construction readiness therefore splits per capability into EXISTING_CAPABILITY_LIVE_PROVEN / CANONICAL_INTEGRATION_VALIDATION_REQUIRED / DELTA_CONSTRUCTION_REQUIRED_IF_VALIDATION_FAILS and is no longer a single chapter-wide cell.',
    admissionEffect: 'REMOVES_CONSTRUCTION_CONFLICT_ONLY',
  },
  {
    chapter: 'CH-03',
    dimension: 'migrationDeploymentReadiness',
    from: 'BLOCKED_EXTERNAL',
    to: 'BLOCKED_EXTERNAL_NON_SEQUENCING',
    founderRuling: 'RULING 4',
    reason:
      'CORS must not block reconstruction sequencing unless canonical evidence proves it a prerequisite of the first wave. It gates the VISUAL half of F051/F052/F056 only; the enumerated consumer audit is CODE_STATIC and reaches no rendered image.',
    admissionEffect: 'PARTITIONS_CHAPTER_INTO_AUDIT_AND_VISUAL',
  },
]

// ------------------------------------------------------- ADMISSION PREDICATE -
const CRITERIA = {
  C1: 'C1 dependency satisfied at source (no unbuilt chapter prerequisite)',
  C2: 'C2 no unresolved founder decision that is load-bearing AT ENTRY',
  C3: 'C3 no protected-boundary crossing whose conditions are OWED',
  C4: 'C4 not a member of a surviving execution cycle',
  C5: 'C5 validation convenable with means available today',
  C6: 'C6 a deterministic completion proof exists',
}

const REQUIRED_ATTRS = [
  'canonicalOwner',
  'canonicalUnitIds',
  'whyExecutableNow',
  'prerequisites',
  'prerequisitesAlreadySatisfied',
  'unresolvedPrerequisites',
  'protectedOrSharedBoundariesTouched',
  'migrationImplications',
  'productionDataImplications',
  'requiredTargetedRegressions',
  'requiredCertification',
  'completionEvidenceRequired',
  'documentationContinuityUpdatesRequired',
]

const CANDIDATES = [
  { unit: 'W1-000', label: 'Shared-system baseline evidence (PBCR conditions 7 and 8)', chapter: 'CH-04', kind: 'NON_MUTATING_EVIDENCE', scope: 'PRE_ENTRY' },
  { unit: 'W1-A', label: 'CH-17 governance MECHANISM half', chapter: 'CH-17', kind: 'GOVERNANCE_MECHANISM', scope: 'LANE_CONT' },
  { unit: 'W1-B', label: 'CH-01 foundation adoption and ratchets', chapter: 'CH-01', kind: 'CONFORMANCE', scope: 'LANE_CONT' },
  { unit: 'W1-C', label: 'CH-02 S1 single-choke-point session establishment', chapter: 'CH-02', kind: 'CONSTRUCTION', scope: 'KEYSTONE_SLICE' },
  { unit: 'W1-D', label: 'CH-02 S2 disjoint fail-closed route classification', chapter: 'CH-02', kind: 'CONSTRUCTION', scope: 'KEYSTONE_SLICE' },
  { unit: 'W1-E', label: 'CH-02 S3 published destination-reconstruction contract', chapter: 'CH-02', kind: 'CONTRACT', scope: 'KEYSTONE_SLICE' },
  { unit: 'W1-F', label: 'CH-03 enumerated consumer AUDIT (read-only)', chapter: 'CH-03', kind: 'AUDIT_NON_MUTATING', scope: 'PARTITIONED_SLICE' },
  { unit: 'W1-X1', label: 'CH-11 security-first head of the content chain', chapter: 'CH-11', kind: 'CONSTRUCTION', scope: 'CHAPTER_HEAD' },
  { unit: 'W1-X2', label: 'CH-04 PHASE 1 (entry evidence, certification slice, device layer)', chapter: 'CH-04', kind: 'CONSTRUCTION', scope: 'CHAPTER_PHASE' },
  { unit: 'W1-X3', label: 'CH-02 S4 draft identity/ownership contract', chapter: 'CH-02', kind: 'CONTRACT', scope: 'KEYSTONE_SLICE' },
]

// Per-candidate evaluation of the six criteria against canonical evidence.
const EVAL = {
  'W1-000': {
    C1: [true, 'No chapter prerequisite. It reads existing deployed behaviour and existing suites; it constructs nothing.'],
    C2: [true, 'AD-CON-5 governs CH-04 CHAPTER ENTRY, not the discharge of conditions 7-8. Ruling 2 requires protected-boundary governance be applied AT the boundary; this unit IS that application.'],
    C3: [true, 'Conditions 7 and 8 are the OWED conditions themselves. Discharging them is non-mutating: a targeted regression run and a health report. No crossing is performed.'],
    C4: [true, 'Not in any cycle. execution-graph-v2 records CH-04 <-> CH-06 in the EVIDENCE graph only, dissolving at bounded-capability granularity; this unit touches neither endpoint.'],
    C5: [true, 'Meetings 97/97 and the realtime suites are LOCAL_AUTOMATED and convenable today. RC-A 509230a and RC-B dfc9027 are present in the tree and statically checkable.'],
    C6: [true, 'Suite output plus a written shared-system health report naming every subsystem crossed. Binary and re-runnable.'],
  },
  'W1-A': {
    C1: [true, 'Stage-5 records that the mechanism half has no prerequisites of any kind. The terminal half is W7 and is out of scope.'],
    C2: [true, 'CH-17 BLOCKED_FOUNDER attaches to the TERMINAL half (chapter authorisations, SupportScreen, PD-1/PD-2). The mechanism authors the register and template that RECEIVE those decisions.'],
    C3: [true, 'PB-10/11/12 are certification SUBJECTS here, not crossings. The mechanism constructs no product capability - an explicit non-goal.'],
    C4: [true, 'Not in any cycle.'],
    C5: [true, 'VS-16 LOCAL_AUTOMATED + CODE_STATIC, convenable now.'],
    C6: [true, 'Register and closure template in governed markdown in BOTH repositories, and each ratchet demonstrated to FAIL on a deliberately introduced real violation (FD-13 precedent).'],
  },
  'W1-B': {
    C1: [true, 'D-01/D-08 satisfied at source: the four C0/C1 authorities closed 2026-08-15. Its own sequencePosition records it gates nothing and is gated by nothing.'],
    C2: [true, 'The 68 SizedBox.shrink() adjudication and PD-1 are governance decisions OWNED BY CH-17 and are not load-bearing at CH-01 entry.'],
    C3: [true, 'PBX-05 is a PROHIBITION, not an owed condition: CO-RC-C0-008 forbids modifying certified Meetings for foundation debt reduction. Observing a prohibition is not a crossing.'],
    C4: [true, 'Not in any cycle.'],
    C5: [true, 'VS-16 convenable now.'],
    C6: [true, 'Ratchets green AND each demonstrated to fail on a real seeded violation.'],
  },
  'W1-C': {
    C1: [true, 'Only stated dependency is CH-01 loading/restoring/expired vocabulary, FROZEN at source (D-08).'],
    C2: [false, 'PD-2 STRUCTURAL DISPOSITION is recorded OPEN (CO-RC-C1-022, DETERMINISTIC_DERIVATION from OPEN_DISPOSITION) and is load-bearing AT ENTRY because it defines the keystone boundary.'],
    C3: [true, 'PBX-10: PB-06 and PB-09 are this chapter own chartered repair. The session hint IS a contract at TokenStore.setSession(); writing it at additional call sites is the defect being repaired, not a new crossing.'],
    C4: [true, 'Not in any cycle.'],
    C5: [true, 'VS-01 SINGLE_AUTHORIZED_BROWSER with a signed-out leg, convenable now.'],
    C6: [true, 'F065 proven on a LIVE refresh. Binary, observable, and the chapter own first gate.'],
  },
  'W1-D': {
    C1: [true, 'Same as W1-C. Route classification consumes no unbuilt chapter.'],
    C2: [false, 'Inherits the PD-2 entry condition from the same keystone.'],
    C3: [true, 'PB-01 Meetings routes are REACHED but not opened: F064/F113 are fixed HERE without modifying Meetings, and every router change carries a targeted Meetings regression. W1-000 establishes the pre-change baseline that makes that regression attributable.'],
    C4: [true, 'Not in any cycle.'],
    C5: [true, 'A live signed-out probe plus the 23 navigation gates and the 103-file/294-site literal ratchet, all LOCAL_AUTOMATED or SINGLE_AUTHORIZED_BROWSER.'],
    C6: [true, 'Fail-closed classification certified by live signed-out probe; 23 gates and the literal ratchet green AFTER the change; Meetings 97/97.'],
  },
  'W1-E': {
    C1: [true, 'A published contract over CH-02 own authority. Consumes nothing unbuilt.'],
    C2: [false, 'Inherits the PD-2 entry condition.'],
    C3: [true, 'Documentary. No boundary reached.'],
    C4: [true, 'Not in any cycle.'],
    C5: [true, 'CODE_STATIC conformance of the contract against S1/S2 as delivered.'],
    C6: [true, 'The contract published in governed markdown and consumed by the S1/S2 closure record.'],
  },
  'W1-F': {
    C1: [true, 'index-chapters records CH-03 dependsOn CH-12, CORRECTED by D-13 / CON-5 / S5D-CON-08: the blocker is an EXTERNAL founder dashboard action, not CH-12 construction. Under RULING 4 that external item does not gate sequencing, and the audit reaches no rendered image.'],
    C2: [true, 'CH-03 BLOCKED_FOUNDER concerns GROUP IDENTITY DOCTRINE (F055 ordering, F056 group avatar) and the verification-label mapping. Those are load-bearing when ACTING on the audit, not when ENUMERATING consumers.'],
    C3: [true, 'PB-05 governs ACTING on the audit. Stage-5 records the enumerated consumer audit as safe, non-mutating work that can begin immediately.'],
    C4: [true, 'Not in any cycle.'],
    C5: [true, 'CODE_STATIC over an enumerated consumer list. No rendered-image leg is claimed.'],
    C6: [true, 'The ENUMERATED consumer list itself - the exit condition PB-05 names for F116, which may NOT be closed by fixing one consumer.'],
  },
  'W1-X1': {
    C1: [true, 'CH-11 has no chapter prerequisite.'],
    C2: [false, 'Stage-5 entry condition: founder ratification that the BIFURCATED ruling answers CH-11 recorded RC-C5 scope question, OR an explicit ruling that it does not. FAIL-CLOSED DEFAULT: TREAT AS GATED. No ruling of 2026-08-18 addressed it.'],
    C3: [true, 'Backend ingestion is disjoint from CH-02 and CH-04 territory.'],
    C4: [true, 'Not in any cycle.'],
    C5: [true, 'Convenable.'],
    C6: [true, 'Available once admitted.'],
  },
  'W1-X2': {
    C1: [true, 'Declared dependsOn CH-01/CH-03/CH-02. Under RULING 2 these are CONSTRUCTION-dimension edges and do not reverse under PB-02; under RULING 1 they are bounded prerequisites, not whole-chapter gates.'],
    C2: [false, 'AD-CON-5 - classification of the completed PB-02 / RC-C6 PRESERVE-list crossing - is listed OUTSTANDING in CH-04 founderActions. SU-5 (RC-C6 blocker discharge) is an analyst inference, not the corpus.'],
    C3: [false, 'PBCR conditions 7 and 8 remain OWED for the historical crossing. RULING 2 requires STOPPING at the boundary and applying protected-boundary/PBCR governance BEFORE proceeding. W1-000 discharges them; until it reports, entry is refused.'],
    C4: [true, 'The CH-04 <-> CH-06 arc is an EVIDENCE-graph artifact that dissolves at bounded-capability granularity; it is not a chapter-level deadlock.'],
    C5: [false, 'VS-02 requires THREE sequential calls within ONE page lifetime with no reload - the only condition under which the F045 accept-freeze root cause manifests. The device layer additionally requires real iOS/Android/Windows devices, a LANE-W0 long-lead request that has not landed.'],
    C6: [true, 'Available once the above are discharged.'],
  },
  'W1-X3': {
    C1: [false, 'The draft identity/ownership contract consumes the identity CONFORMANCE GATE that CH-03 publishes in W2. Drafting it now would author identity ownership ahead of its owning chapter.'],
    C2: [false, 'Inherits PD-2, and additionally depends on the group identity doctrine that does not exist.'],
    C3: [true, 'Documentary.'],
    C4: [true, 'Not in any cycle.'],
    C5: [true, 'CODE_STATIC.'],
    C6: [true, 'Available once admitted.'],
  },
}

const ATTR = JSON.parse(readFileSync(resolve(HERE, 'first-wave-attributes.json'), 'utf8'))

// ------------------------------------------------------------------ COMPUTE --
const results = CANDIDATES.map((c) => {
  const e = EVAL[c.unit]
  if (!e) throw new Error('FAIL-CLOSED: no evaluation for ' + c.unit)
  const criteria = {}
  const failed = []
  for (const key of Object.keys(CRITERIA)) {
    if (!e[key]) throw new Error('FAIL-CLOSED: criterion ' + key + ' unevaluated for ' + c.unit)
    criteria[key] = { criterion: CRITERIA[key], satisfied: e[key][0], evidence: e[key][1] }
    if (!e[key][0]) failed.push(key)
  }
  // CONDITIONAL is reserved for a SINGLE failing criterion that is a founder ACT
  // (C2) already scheduled in LANE-W0. Anything else REFUSES admission.
  let admission
  if (failed.length === 0) admission = 'ADMITTED_UNCONDITIONAL'
  else if (failed.length === 1 && failed[0] === 'C2') admission = 'ADMITTED_CONDITIONAL_ON_FOUNDER_ACT'
  else admission = 'REFUSED'

  const a = ATTR[c.unit]
  if (!a) throw new Error('FAIL-CLOSED: no 13-attribute record for ' + c.unit)
  const keys = Object.keys(a)
  if (keys.length !== 13) throw new Error('FAIL-CLOSED: ' + c.unit + ' has ' + keys.length + ' attributes, required 13')
  for (const k of REQUIRED_ATTRS)
    if (!(k in a)) throw new Error('FAIL-CLOSED: ' + c.unit + ' missing attribute ' + k)

  return { ...c, admission, failedCriteria: failed, criteria, attributes: a }
})

const admitted = results.filter((r) => r.admission !== 'REFUSED')
const refused = results.filter((r) => r.admission === 'REFUSED')

// Ownership containment: every canonical id an admitted unit touches must be
// owned by that unit's canonical chapter. Fail closed on any leak.
const touched = { findings: new Set(), obligations: new Set() }
for (const r of admitted) {
  const own = byId[r.chapter]
  if (!own) throw new Error('FAIL-CLOSED: unknown chapter ' + r.chapter)
  for (const id of r.attributes.canonicalUnitIds.findings) {
    if (!own.findings.ids.includes(id)) throw new Error('FAIL-CLOSED: finding ' + id + ' not owned by ' + r.chapter)
    touched.findings.add(id)
  }
  for (const id of r.attributes.canonicalUnitIds.obligations) {
    if (!own.obligations.ids.includes(id)) throw new Error('FAIL-CLOSED: obligation ' + id + ' not owned by ' + r.chapter)
    touched.obligations.add(id)
  }
}

// The frozen gate must not be reachable by any admitted unit.
const GATE = { from: 'CH-13', to: 'CH-05' }
const entered = new Set(admitted.map((r) => r.chapter))
if (entered.has(GATE.from) || entered.has(GATE.to))
  throw new Error('FAIL-CLOSED: an admitted unit enters the RC-C5 frozen gate territory')
if (!graph.preservedGate) throw new Error('FAIL-CLOSED: execution-graph-v2 records no preserved gate')

const out = {
  type: 'FIRST_EXECUTABLE_WAVE',
  artifact: 'first-wave-v2.json',
  date: '2026-08-18',
  status: 'DERIVED_FOR_FOUNDER_AUTHORIZATION_NOT_EXECUTED',
  derivation:
    'Re-derived from canonical evidence under the four 2026-08-18 pre-execution rulings. Stage-5 W1 was NOT assumed correct and did NOT survive unchanged.',
  rulingOverridesApplied: RULING_OVERRIDES,
  admissionPredicate: {
    criteria: CRITERIA,
    failClosed:
      'An unevaluated criterion throws. CONDITIONAL is permitted ONLY for a single C2 (founder act) failure already scheduled in LANE-W0; every other failure REFUSES.',
  },
  units: results,
  summary: {
    candidatesEvaluated: results.length,
    admittedUnconditional: results.filter((r) => r.admission === 'ADMITTED_UNCONDITIONAL').map((r) => r.unit),
    admittedConditional: results.filter((r) => r.admission === 'ADMITTED_CONDITIONAL_ON_FOUNDER_ACT').map((r) => r.unit),
    refused: refused.map((r) => ({ unit: r.unit, failed: r.failedCriteria })),
    chaptersEntered: [...entered].sort(),
    canonicalFindingsTouched: [...touched.findings].sort(),
    canonicalObligationsTouched: [...touched.obligations].sort(),
  },
  deltaFromStage5W1: {
    stage5W1: ['CH-02 keystone S1-S4', 'CH-04 PHASE 1', 'CH-11', 'CH-01 + CH-17-mech in LANE-CONT'],
    removed: [
      {
        unit: 'CH-04 PHASE 1',
        reason:
          'REFUSED on C2 (AD-CON-5 outstanding), C3 (PBCR 7-8 OWED - RULING 2 requires stopping at the boundary) and C5 (VS-02 three-sequential-call condition and real devices unavailable). RULING 3 removed the CONSTRUCTION conflict; it did not discharge the protected-boundary conditions or the environmental blocker.',
      },
      { unit: 'CH-02 S4', reason: 'REFUSED on C1 and C2: consumes the identity conformance gate CH-03 publishes in W2.' },
    ],
    downgraded: [
      {
        unit: 'CH-11',
        from: 'IN W1 UNCONDITIONALLY',
        to: 'ADMITTED_CONDITIONAL_ON_FOUNDER_ACT',
        reason:
          'Stage-5 own entry condition sets a FAIL-CLOSED default of GATED pending founder ratification of the BIFURCATED ruling scope question. No 2026-08-18 ruling addressed it.',
      },
    ],
    added: [
      {
        unit: 'W1-000',
        reason:
          'RULING 2 makes the OWED PBCR conditions 7-8 a boundary obligation that must be discharged BEFORE any protected crossing. It is non-mutating, and it is simultaneously a prerequisite of CH-04 entry AND the attribution baseline for every CH-02 S2 router regression.',
      },
      {
        unit: 'W1-F',
        reason:
          'RULING 4 removes CORS from the sequencing path. CH-03 partitions: the CODE_STATIC enumerated consumer audit is executable now; the rendered-image half stays blocked and stays in W2.',
      },
    ],
  },
  whatIsNotClaimed: [
    'No chapter CLOSES in this wave.',
    'No founder gate is weakened. CH-13 -> CH-05 (RC-C5) is untouched and is not reached by any admitted unit.',
    'PB-02 is not weakened. No admitted unit performs a protected-layer corrective repair; W1-000 discharges owed conditions without crossing.',
    'F065 live proof has NOT occurred. It is IMPLEMENTED_NOT_LIVE_CERTIFIED and the live proof IS the gate.',
    'The wave does not authorize CORS, migrations, R2, deployment or production-data mutation.',
    'No finding or obligation state is promoted by this derivation.',
  ],
}

writeFileSync(resolve(RUN, 'first-wave-v2.json'), JSON.stringify(out, null, 1))
console.log('candidates      :', results.length)
console.log('unconditional   :', out.summary.admittedUnconditional.join(', '))
console.log('conditional     :', out.summary.admittedConditional.join(', '))
console.log('refused         :', refused.map((r) => r.unit + '[' + r.failedCriteria.join('') + ']').join(', '))
console.log('chapters entered:', out.summary.chaptersEntered.join(', '))
console.log('F touched       :', out.summary.canonicalFindingsTouched.length, out.summary.canonicalFindingsTouched.join(' '))
console.log('CO touched      :', out.summary.canonicalObligationsTouched.length)
console.log('OK -> first-wave-v2.json')
