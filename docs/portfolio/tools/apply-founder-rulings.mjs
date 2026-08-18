#!/usr/bin/env node
/**
 * APPLY FOUNDER RULINGS (2026-08-18) TO THE REBUILT CO AXIS.
 *
 * Deterministic. Every change traces to a named ruling; nothing is inferred here.
 * Produces the classification+ownership overlay for the v2 register.
 *
 * Usage: node apply-founder-rulings.mjs <runRoot>
 */

import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.argv[2]
if (!root) { console.error('usage: node apply-founder-rulings.mjs <runRoot>'); process.exit(2) }
const RCD = join(root, '02-reconcile'), SY = join(root, '03-synthesis')
const rd = (p) => JSON.parse(readFileSync(p, 'utf8'))

const reg = rd(join(RCD, 'chartered-obligation-register-v2.json'))
const ownA = rd(join(SY, 'ownership-co-a.json'))
const ownB = rd(join(SY, 'ownership-co-b.json'))
const clsB = rd(join(SY, 'classification-co-b.json'))

// ── classificationBasis vocabulary (RULING H) ───────────────────────────────
// Distinguishes how a classification was arrived at. Inference must never be
// convertible into historical fact by reading the register alone.
const BASIS = {
  RECORDED: 'EXPLICIT_RECORDED_STATE',
  RULING: 'EXPLICIT_FOUNDER_RULING',
  DERIVED: 'DETERMINISTIC_DERIVATION',
  INFERRED: 'ANALYTICAL_INFERENCE',
  UNRESOLVED: 'UNRESOLVED_INSUFFICIENT_EVIDENCE',
}

// ── prior ownership + classification ────────────────────────────────────────
const owner = new Map(), cls = new Map(), conf = new Map(), rat = new Map()
for (const a of ownA.assignments) {
  owner.set(a.id, a.canonicalChapter || a.canonicalOwner)
  if (a.obligationClass) { cls.set(a.id, a.obligationClass); rat.set(a.id, a.ownershipRationale) }
}
for (const a of ownB.assignments) owner.set(a.id, a.canonicalChapter || a.canonicalOwner)
for (const c of clsB.classifications) {
  cls.set(c.id, c.obligationClass); conf.set(c.id, c.classificationConfidence); rat.set(c.id, c.classificationRationale)
}

// ── RULING 2 — RC-C10 completed set is EXACTLY the two founder-evidenced ────
// FOUNDER_DECIDED != COMPLETED_OR_SUPERSEDED. IMPLEMENTED != VALIDATED !=
// LIVE_CERTIFIED. ACTIVE_CONSTRAINT != DISCHARGED_OBLIGATION.
const RC_C10_RECLASS = {
  'CO-RC-C10-001': {
    obligationClass: 'OUTSTANDING_CONSTRUCTION',
    dimensions: { founderDecided: true, implemented: false, structurallyComplete: false, validated: false, liveCertified: false, activeConstraint: true, dischargedObligation: false },
    rationale: 'FD-5 is a decided founder ruling AND a LIVE CONSTRAINT on all remaining Live work. The decision is made; the obligation it imposes — that Live BE a governed state of an owning Thread/Space — is not discharged while Live construction is incomplete. Classifying it completed would make an active constraint appear discharged.',
  },
  'CO-RC-C10-002': {
    obligationClass: 'OUTSTANDING_CONSTRUCTION',
    dimensions: { founderDecided: true, implemented: false, structurallyComplete: false, validated: false, liveCertified: false, activeConstraint: true, dischargedObligation: false },
    rationale: 'The discovery correction as an ACT is finished, but its own text states "The vocabulary exists; the mechanism does not." The mechanism is construction and remains outstanding. The superseded state clause is separately captured by CO-RC-C10-013.',
  },
  'CO-RC-C10-003': {
    obligationClass: 'VALIDATION_OR_GATE_ONLY',
    dimensions: { founderDecided: true, implemented: true, structurallyComplete: true, validated: false, liveCertified: false, activeConstraint: true, dischargedObligation: false },
    rationale: 'The origination correction is founder-frozen AND implemented (single door behind the FD-5 ritual; backend fence live-verified 400/404). IMPLEMENTED is recorded because evidence exists. VALIDATED and LIVE_CERTIFIED are NOT inferred — and this correction invalidated the earlier Live proofs, so re-proof is owed.',
  },
}
const RC_C10_FOUNDER_COMPLETED = ['CO-RC-C10-013', 'CO-RC-C10-014']

// ── RULING 3 — CO-RC-C7-015 reconciled ──────────────────────────────────────
const C7_015 = {
  obligationClass: 'OUTSTANDING_CONSTRUCTION',
  rationale: 'FOUNDER RULING: RECONCILED — NOT CONTRADICTORY. "Distinct governed communication FORM" != "separate PRODUCT". The charter obligation ("Correspondence as a distinct governed communication form — sharing infrastructure but not semantics") and the 2026-08-16 amendment ("C7 does NOT recreate Correspondence as a product") coexist. The build obligation therefore STANDS and is outstanding. Its prior UNKNOWN was a contradiction condition, now resolved by ruling — not by analysis.',
  priorState: 'UNKNOWN (conflicting frozen records)',
}

// ── newly discovered COs: deterministic class from the source type token ────
const NEW_CLASS_BY_TYPE = {
  OWNERSHIP_VOID: 'FOUNDER_ACTION_ONLY',
  OPEN_DISPOSITION: 'FOUNDER_ACTION_ONLY',
  UNRESOLVED_DISPOSITION: 'FOUNDER_ACTION_ONLY',
  OPEN_FOUNDER_GAP: 'FOUNDER_ACTION_ONLY',
  UNRESOLVED: 'FOUNDER_ACTION_ONLY',
  UNASSIGNED_SURFACE: 'FOUNDER_ACTION_ONLY',
  SCOPE_UNADDRESSED: 'OUTSTANDING_CONSTRUCTION',
  PRECONDITION_UNMET: 'VALIDATION_OR_GATE_ONLY',
}

// Ownership for the 9 new COs, taken from the ARCHITECT'S OWN recorded
// resolutions — never from name similarity.
const NEW_OWNER = {
  'CO-RC-C1-021': ['CH-17', 'Architecture: "PD-1 ... The DISPOSITION DECISION is owned by CH-17 and is a founder act." Same for the PD-2 pair.'],
  'CO-RC-C1-022': ['CH-17', 'Architecture: PD-2 split — structural half CH-02, experience half CH-10, but "The disposition decision itself is owned by CH-17 and must resolve before C11."'],
  'CO-RC-C2-037': ['CH-03', 'Identity consumption and presentation truth owns institution->person residue disposition; CH-03 governing outcome is that canonical identity is the only identity any surface renders.'],
  'CO-RC-C3-025': ['CH-05', 'Architecture: "GAP-1 Settings / Personal Controls: Owned by CH-05 Attention, Notification Preference & Personal Controls. Founder placement ratification required."'],
  'CO-RC-C3-026': ['CH-14', 'Architecture grants the publication-semantics charter to CH-14 Publication, Discovery & Public Entry.'],
  'CO-RC-C6-029': ['CH-04', 'The Meetings presentation-convergence demolition target is shared-presentation work; CH-04 owns the shared component family that never owns semantic meaning. FD-4 permits presentation convergence slice-by-slice.'],
  'CO-RC-C7-025': ['CH-07', 'The Correspondence architectural convergence verdict is RC-C7 chapter-owned; CH-07 owns institutional communication as a governed form of the canonical Conversation.'],
  'CO-RC-C9-029': ['CH-17', 'Architecture: "SupportScreen — DELIBERATELY UNOWNED as construction. No chapter takes it. The DISPOSITION DECISION is owned by CH-17." The obligation is the decision, not the surface.'],
  'CO-RC-C9-030': ['CH-16', 'C9 precondition/gate obligation; CH-16 owns cross-platform, native surfaces and release delivery.'],
}

// ── build the overlay ───────────────────────────────────────────────────────
const out = []
let reclassified = 0, newlyAssigned = 0
for (const c of reg.obligations) {
  const id = c.id
  let obligationClass = cls.get(id)
  let basis = BASIS.INFERRED
  let rationale = rat.get(id) || null
  let confidence = conf.get(id) || null
  let dimensions = null
  let own = owner.get(id) || null

  if (c.registerVersion === 'v2-new') {
    obligationClass = NEW_CLASS_BY_TYPE[c.scopeArea] || 'UNKNOWN'
    basis = BASIS.DERIVED
    rationale = 'Deterministically derived from the source entry type token "' + c.scopeArea + '" under the v2 obligation-bearing rule. No analytical judgement applied.'
    confidence = null
    const o = NEW_OWNER[id]
    if (o) { own = o[0]; newlyAssigned++ }
  }

  if (RC_C10_RECLASS[id]) {
    obligationClass = RC_C10_RECLASS[id].obligationClass
    dimensions = RC_C10_RECLASS[id].dimensions
    rationale = RC_C10_RECLASS[id].rationale
    basis = BASIS.RULING
    confidence = null
    reclassified++
  } else if (RC_C10_FOUNDER_COMPLETED.includes(id)) {
    obligationClass = 'COMPLETED_OR_SUPERSEDED'
    basis = BASIS.RULING
    dimensions = { founderDecided: true, implemented: true, structurallyComplete: true, validated: false, liveCertified: false, activeConstraint: false, dischargedObligation: true }
  } else if (id === 'CO-RC-C7-015') {
    obligationClass = C7_015.obligationClass
    rationale = C7_015.rationale
    basis = BASIS.RULING
    confidence = null
    reclassified++
  }

  out.push({
    id, rcChapter: c.rcChapter, charteredBy: c.rcChapter,
    canonicalChapter: own,
    obligationClass,
    classificationBasis: basis,
    classificationRationale: rationale,
    classificationConfidence: confidence,
    dimensions,
    registerVersion: c.registerVersion,
    provenance: c.provenance,
  })
}

const byClass = {}, byBasis = {}
for (const r of out) {
  byClass[r.obligationClass] = (byClass[r.obligationClass] || 0) + 1
  byBasis[r.classificationBasis] = (byBasis[r.classificationBasis] || 0) + 1
}

writeFileSync(join(SY, 'co-classification-v2.json'), JSON.stringify({
  artifact: 'CO_CLASSIFICATION_AND_OWNERSHIP_V2',
  type: 'ANALYTICAL_PROPOSAL',
  date: '2026-08-18',
  rulingsApplied: [
    'RULING 2 — RC-C10 completed set is EXACTLY CO-RC-C10-013 and -014; the three disputed rows reclassified with dimensions preserved',
    'RULING 3 — CO-RC-C7-015 reconciled: distinct governed communication FORM != separate PRODUCT',
    'RULING 5 — 9 newly discovered COs classified deterministically from their source type token',
    'RULING H — classificationBasis added to every obligation',
  ],
  schemaLimitationReported: 'The six-value obligation taxonomy cannot express a multidimensional state (FOUNDER_DECIDED + IMPLEMENTED + NOT VALIDATED + ACTIVE_CONSTRAINT). Rather than collapse it, a `dimensions` object is carried on the affected RC-C10 rows. The taxonomy itself was NOT widened without founder authority.',
  classificationBasisVocabulary: Object.values(BASIS),
  totals: { obligations: out.length, reclassifiedByRuling: reclassified, newlyAssignedOwners: newlyAssigned },
  byClass, byBasis,
  classifications: out,
}, null, 1))

console.log('obligations        :', out.length)
console.log('reclassified (rule):', reclassified)
console.log('new owners assigned:', newlyAssigned)
console.log('byClass :', JSON.stringify(byClass))
console.log('byBasis :', JSON.stringify(byBasis))
const noOwner = out.filter((r) => !r.canonicalChapter)
console.log('without owner      :', noOwner.length, noOwner.slice(0, 10).map((r) => r.id).join(', '))
