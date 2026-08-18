#!/usr/bin/env node
// APPLY PART-1 FOUNDER RULINGS (2026-08-18)
//
// Ruling 1 — DEFECT-1 (realtime room goldens) assigned to CH-04 and made a
//            certification/closure requirement. Not waived, not permanent.
// Ruling 2 — Meetings 97/97 recorded as SUPERSEDED_BY_CURRENT_VERIFICATION by
//            the current 118-pass evidence. Evidence supersession, NOT
//            historical mutation: the historical figure is retained verbatim.
//
// Deterministic and idempotent. Fails closed if an anchor it expects is absent.
import { readFileSync, writeFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const RUN = resolve(HERE, '../run/stage0-2026-08-18/05-execution')
const P = resolve(RUN, 'index-chapters.json')
const doc = JSON.parse(readFileSync(P, 'utf8'))
const ch04 = doc.chapters.find((c) => c.id === 'CH-04')
if (!ch04) throw new Error('FAIL-CLOSED: CH-04 not found')

// ── RULING 1 ────────────────────────────────────────────────────────────────
const DEFECT1_REQ =
  'DEFECT-1 (founder ruling 2026-08-18, W1-000 evidence): test/realtime_room_golden_test.dart is @Skip-ped in its entirety for pre-existing fixture rot, so realtime RENDERED-ROOM PRESENTATION currently has NO automated visual proof. Meaningful realtime-room presentation verification must be RESTORED OR REPLACED as a condition of this chapter closing. The gap is assigned, not waived, and is not accepted as permanent.'
const DEFECT1_NOT_PROVEN =
  'DEFECT-1 COROLLARY: the 333-pass realtime suite (290 backend + 43 frontend) certifies SEMANTICS AND LIFECYCLE ONLY. It may NEVER be represented as proving rendered-room presentation. A green realtime suite is not visual coverage.'
const DEFECT1_BOUNDARY =
  'DEFECT-1 BOUNDARY: the protected Meetings surface (PB-01) may NOT be modified in order to repair this defect. All shared/protected-boundary governance, including PBCR, continues to apply to any work done under it.'

for (const req of [DEFECT1_REQ, DEFECT1_NOT_PROVEN, DEFECT1_BOUNDARY]) {
  if (!ch04.certificationRequirements.includes(req)) ch04.certificationRequirements.push(req)
}

ch04.assignedDefects = ch04.assignedDefects || []
if (!ch04.assignedDefects.some((d) => d.id === 'DEFECT-1')) {
  ch04.assignedDefects.push({
    id: 'DEFECT-1',
    title: 'Realtime room golden coverage skipped for pre-existing rot',
    assignedBy: 'FOUNDER RULING 2026-08-18 (Part 1 acceptance, ruling 1)',
    discoveredBy: 'W1-000 shared-system health report (PBCR condition 8)',
    evidence: 'aura_final/test/realtime_room_golden_test.dart — @Skip("Pre-existing rot — RealtimeRoomScreen fixtures drifted; needs a dedicated revival pass with --update-goldens.")',
    statement: 'Realtime rendered presentation currently lacks automated visual proof despite the broader realtime suite being green.',
    classification: 'PRE_EXISTING_COVERAGE_DEFECT',
    state: 'OPEN_ASSIGNED',
    waived: false,
    acceptedAsPermanent: false,
    closureRequirement: 'Restoration or replacement of meaningful realtime-room presentation verification is a CH-04 certification/closure requirement.',
    prohibitions: [
      'The 333-pass realtime suite may not be represented as proving rendered-room presentation.',
      'The protected Meetings surface may not be modified to repair this defect.',
    ],
    doesNotAuthorize:
      'This assignment does NOT authorize any unrelated CH-04 implementation ahead of its proper execution wave. CH-04 remains un-entered.',
    isNewCanonicalUnit: false,
    accountingNote:
      'DEFECT-1 is a coverage defect recorded against an existing chapter. It is NOT a new finding and NOT a new chartered obligation, so the 143 + 308 = 451 canonical accounting is unchanged by this ruling.',
  })
}

// ── RULING 2 ────────────────────────────────────────────────────────────────
// The historical string is retained verbatim wherever it already appears; a
// supersession record is added alongside it. Nothing is rewritten.
const stale = ch04.certificationRequirements.findIndex((r) => r.includes('(97/97)'))
if (stale === -1) throw new Error('FAIL-CLOSED: the historical 97/97 requirement string was not found; ruling 2 expects it to still be there')

ch04.evidenceSupersessions = ch04.evidenceSupersessions || []
if (!ch04.evidenceSupersessions.some((e) => e.subject === 'MEETINGS_TARGETED_REGRESSION')) {
  ch04.evidenceSupersessions.push({
    subject: 'MEETINGS_TARGETED_REGRESSION',
    ruledBy: 'FOUNDER RULING 2026-08-18 (Part 1 acceptance, ruling 2)',
    kind: 'EVIDENCE_SUPERSESSION_NOT_HISTORICAL_MUTATION',
    historicalEvidence: {
      value: '97/97',
      status: 'RETAINED_AS_HISTORICAL_VERIFICATION_EVIDENCE',
      note: 'The historical figure is NOT rewritten. It remains verbatim in certificationRequirements[2] and in every Stage 3/5 artifact that recorded it.',
    },
    currentEvidence: {
      value: '118 PASS',
      composition: '90 backend (8 suites) + 28 frontend',
      capturedBy: 'W1-000, 2026-08-18',
      status: 'CURRENT_VERIFICATION_EVIDENCE',
    },
    operativeRule:
      'For current health and certification purposes the 118-pass evidence is operative. The historical 97/97 is SUPERSEDED_BY_CURRENT_VERIFICATION and retains its provenance.',
    suiteDirection: 'GREW — 97 to 118. This is not a coverage loss.',
    appliesTo:
      'Any operative or current-state artifact must cite 118. Any historical artifact keeps 97/97 with its date.',
  })
}

writeFileSync(P, JSON.stringify(doc, null, 1))

const summary = {
  type: 'PART1_FOUNDER_RULINGS_APPLIED',
  date: '2026-08-18',
  ruling1: {
    subject: 'DEFECT-1 realtime room goldens',
    assignedTo: 'CH-04',
    certificationRequirementsAdded: 3,
    waived: false,
    canonicalAccountingChanged: false,
  },
  ruling2: {
    subject: 'Meetings targeted regression figure',
    kind: 'EVIDENCE_SUPERSESSION',
    historicalRetainedVerbatim: true,
    historicalStringStillPresentAtIndex: stale,
    operativeValue: '118 PASS',
  },
  ruling5PreservedOutcomes: [
    'W1-000 PBCR conditions 7 and 8 discharged on current evidence',
    'W1-A CH-17 register and closure mechanism accepted',
    'W1-B 8/8 anti-drift ratchets accepted as ENFORCING',
    'W1-F consumer enumeration accepted as evidentiary input to F116/F053',
    'F116 remains PARTIALLY_VALIDATED',
    'F053 remains PARTIALLY_VALIDATED',
    'No chapter closes from Part 1',
    'No unproven state promoted',
    '451/451 canonical units and 17/17 chapters intact',
  ],
  executionHold: 'PART 2 NOT STARTED. Decision hold pending PD-1 and PD-2 rulings.',
}
writeFileSync(resolve(RUN, 'part1-rulings-applied.json'), JSON.stringify(summary, null, 1))
console.log('CH-04 certificationRequirements:', ch04.certificationRequirements.length)
console.log('CH-04 assignedDefects        :', ch04.assignedDefects.length)
console.log('CH-04 evidenceSupersessions  :', ch04.evidenceSupersessions.length)
console.log('historical 97/97 retained at index', stale)
console.log('OK')
