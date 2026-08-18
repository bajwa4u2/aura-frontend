#!/usr/bin/env node
// APPLY FOUNDER RULINGS PD-1 AND PD-2 (2026-08-18) — canonical, deterministic,
// idempotent. Uses the established supersession discipline: nothing historical
// is rewritten; dispositions are recorded alongside the records they resolve.
import { readFileSync, writeFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const RUN = resolve(HERE, '../run/stage0-2026-08-18')
const EX = resolve(RUN, '05-execution')
const rd = (p) => JSON.parse(readFileSync(p, 'utf8'))

// ── 1. Chapter artifacts ────────────────────────────────────────────────────
const P = resolve(EX, 'index-chapters.json')
const doc = rd(P)
const ch = (id) => {
  const c = doc.chapters.find((x) => x.id === id)
  if (!c) throw new Error('FAIL-CLOSED: chapter not found ' + id)
  return c
}
const CH02 = ch('CH-02'), CH10 = ch('CH-10')

const PD2 = {
  id: 'PD-2',
  name: 'Authentication & Account Entry',
  ruledBy: 'FOUNDER RULING 2026-08-18',
  status: 'RESOLVED',
  disposition: 'RATIFIED_SPLIT — CH-02 owns STRUCTURE; CH-10 owns ACCOUNT-ENTRY EXPERIENCE.',
  natureOfRuling:
    'Recognition of convergent canonical evidence already recorded INDEPENDENTLY in CH-02 and CH-10 founderActions, and of the corresponding built-system seam. NOT a newly invented decomposition.',
  constraints: [
    'Do not enlarge either chapter beyond that boundary.',
    'Do not create a new authority.',
    'Do not allow implementation to redefine the split.',
  ],
  supersedes: {
    record: 'CO-RC-C1-022 — "PD-2 STRUCTURAL DISPOSITION remains OPEN"',
    treatment: 'RETAINED VERBATIM as historical evidence; superseded as to current status only.',
  },
}

CH02.productDispositions = CH02.productDispositions || []
if (!CH02.productDispositions.some((d) => d.id === 'PD-2')) {
  CH02.productDispositions.push({
    ...PD2,
    ownedHere: 'STRUCTURE — session establishment, route classification, redirect/destination reconstruction, and verification gating as structural decisions.',
    notOwnedHere: 'The account-entry EXPERIENCE surfaces (login/register/forgot/reset presentation, conversion, copy) belong to CH-10.',
    unblocks: ['W1-C (S1)', 'W1-D (S2)', 'W1-E (S3)'],
  })
}

// The seam enumeration is an IMPLEMENTATION/CERTIFICATION obligation created by
// making the already-frozen structural seam explicit — not a new decision.
const SEAM_REQ =
  'PD-2 SEAM ENUMERATION (founder ruling 2026-08-18): CH-02 S3 MUST publish an explicit seam enumeration identifying, at minimum: (1) the structural auth/destination routes governed by CH-02; (2) the account-entry experience surfaces governed by CH-10; (3) the redirect/destination reconstruction contract; (4) the ownership boundary at each crossing; (5) any shared dependency; (6) the fail-closed behaviour where destination reconstruction cannot be proven. This is an implementation/certification obligation, NOT a founder decision.'
if (!CH02.certificationRequirements.includes(SEAM_REQ)) CH02.certificationRequirements.push(SEAM_REQ)

CH10.productDispositions = CH10.productDispositions || []
if (!CH10.productDispositions.some((d) => d.id === 'PD-2')) {
  CH10.productDispositions.push({
    ...PD2,
    ownedHere: 'ACCOUNT-ENTRY EXPERIENCE — the user-facing account-entry/acquisition surfaces.',
    notOwnedHere: 'Structural destination/reconstruction authority belongs to CH-02.',
    consumesFrom: 'CH-02 S3 seam enumeration and destination-reconstruction contract.',
  })
}

// ── 2. PD-1 ─────────────────────────────────────────────────────────────────
const g5 = rd(resolve(EX, 'pd1-g5-count-reconciliation.json'))
if (g5.escalateToFounder) throw new Error('FAIL-CLOSED: PD-1 G5 reconciliation demands founder escalation')

const remainder = rd(resolve(EX, 'w1b-remainder-ownership.json'))
const pd1Rows = remainder.rows.filter((r) => r.owner === 'PD-1')
const pd1Files = [...new Set(pd1Rows.map((r) => r.path))].sort()
const pd1Sites = pd1Rows.reduce((a, r) => a + r.sites, 0)
if (pd1Files.length !== 11) throw new Error('FAIL-CLOSED: expected 11 PD-1 files, got ' + pd1Files.length)
if (pd1Sites !== 52) throw new Error('FAIL-CLOSED: expected 52 PD-1 sites, got ' + pd1Sites)

const byRule = {}
for (const r of pd1Rows) byRule[r.rule] = (byRule[r.rule] || 0) + r.sites

const PD1 = {
  id: 'PD-1',
  name: 'Platform Administration',
  ruledBy: 'FOUNDER RULING 2026-08-18',
  status: 'RESOLVED_FOR_THIS_RECONSTRUCTION_PROGRAMME',
  productStanding: {
    isLegitimateShippedCapability: true,
    deprecated: false,
    demolished: false,
    architecturallyInvalid: false,
    removedFromAura: false,
    note: 'Platform Administration remains a legitimate shipped Aura product capability. The ruling is about RECONSTRUCTION SCOPE, not about the product.',
  },
  disposition: 'OUT_OF_CURRENT_RECONSTRUCTION_SCOPE',
  readmission: 'A future founder-authorized admission may explicitly bring it into reconstruction. Until then there is no retirement condition, and that absence IS the recorded disposition.',
  prohibitions: [
    'Do not invent a reconstruction chapter merely to own its debt.',
    'Do not distort an existing chapter to absorb it.',
    'Do not modify the Platform Administration surface merely to satisfy reconstruction debt accounting.',
  ],
  debtTreatment: {
    classification: 'FROZEN_BY_RULE / OUT_OF_CURRENT_RECONSTRUCTION_SCOPE',
    files: pd1Files.length,
    sites: pd1Sites,
    byRule,
    preservedInGovernedRegister: true,
    ownerlessByReconstruction: 'INTENTIONAL, NOT NEGLECTED',
    countsAsOrdinaryExecutableDebt: false,
    stillMeasured: 'The C0 anti-drift ratchet continues to hold these counts: they may never rise, and if they fall the gate fails until the baseline is updated. Exclusion from reconstruction is NOT exclusion from measurement.',
  },
  distinctFromPbProtection:
    'Semantically distinct from PB protection. PB-01 Meetings is frozen because modification is PROHIBITED on a certified protected surface (CO-RC-C0-008). PD-1 is frozen because the surface is OUT OF SCOPE for this reconstruction. Both are FROZEN_BY_RULE; the rules differ and must not be conflated.',
  doesNotExempt: {
    sharedRuntimeAndSecurityAuthorities: true,
    statement:
      'PD-1 does NOT exempt Platform Administration from shared runtime/security authorities. CH-02 S2 fail-closed classification of /admin REMAINS APPLICABLE where the shared auth/routing boundary requires it. Scope exclusion does not create a security or shared-authority bypass.',
  },
  g5CountReconciliation: {
    historical: { value: 34, status: 'RETAINED_AS_HISTORICAL_EVIDENCE_WITH_PROVENANCE' },
    operative: { value: 35, status: 'CURRENT_OPERATIVE_COUNT' },
    cause: g5.cause,
    escalated: false,
    note: 'Site populations proven identical file-by-file; 34 was a summation error in a summary line. Product scope and governance intent unchanged.',
  },
  supersedes: {
    record: 'CO-RC-C11-005 — "PD-1 Platform Administration disposition (11 files / 34 G5 sites) — no owning chapter in the approved roadmap"',
    treatment: 'RETAINED VERBATIM as historical evidence; superseded as to current status only — the obligation is now DISPOSED_BY_RULING rather than REMAINING.',
  },
  files: pd1Files,
}

doc.productDispositions = doc.productDispositions || []
for (const d of [PD2, PD1]) {
  if (!doc.productDispositions.some((x) => x.id === d.id)) {
    doc.productDispositions.push(d.id === 'PD-1' ? PD1 : PD2)
  }
}
writeFileSync(P, JSON.stringify(doc, null, 1))

// ── 3. Rewrite the remainder register with the PD-1 ruling applied ──────────
for (const r of remainder.rows) {
  if (r.owner !== 'PD-1') continue
  r.ownerNote = PD1.disposition + ' — ' + PD1.readmission
  r.debtClass = 'FROZEN_BY_RULE'
  r.frozenReason = 'OUT_OF_CURRENT_RECONSTRUCTION_SCOPE (founder ruling 2026-08-18)'
  r.countsAsExecutableDebt = false
  r.retirementCondition = 'NO RETIREMENT CONDITION WHILE OUT OF SCOPE. Lifted only by a future founder-authorized admission into reconstruction. The absence of a condition is the disposition, not an omission.'
}
for (const r of remainder.rows) {
  if (r.owner !== 'PB-01') continue
  r.debtClass = 'FROZEN_BY_RULE'
  r.frozenReason = 'PROTECTED_SURFACE_MODIFICATION_PROHIBITED (CO-RC-C0-008)'
  r.countsAsExecutableDebt = false
}
for (const r of remainder.rows) {
  if (r.debtClass) continue
  r.debtClass = 'EXECUTABLE'
  r.countsAsExecutableDebt = true
}

const frozen = remainder.rows.filter((r) => !r.countsAsExecutableDebt)
const executable = remainder.rows.filter((r) => r.countsAsExecutableDebt)
remainder.debtSeparation = {
  rule: 'Frozen debt must be explicitly distinguishable from executable debt and must never be reported as ordinary outstanding reconstruction work.',
  executable: { files: executable.length, sites: executable.reduce((a, r) => a + r.sites, 0) },
  frozenByRule: {
    files: frozen.length,
    sites: frozen.reduce((a, r) => a + r.sites, 0),
    reasons: {
      OUT_OF_CURRENT_RECONSTRUCTION_SCOPE: {
        owner: 'PD-1',
        files: pd1Files.length, sites: pd1Sites,
        basis: 'Founder ruling 2026-08-18',
      },
      PROTECTED_SURFACE_MODIFICATION_PROHIBITED: {
        owner: 'PB-01',
        files: remainder.rows.filter((r) => r.owner === 'PB-01').length,
        sites: remainder.rows.filter((r) => r.owner === 'PB-01').reduce((a, r) => a + r.sites, 0),
        basis: 'CO-RC-C0-008',
      },
    },
    semanticallyDistinct: PD1.distinctFromPbProtection,
  },
}
writeFileSync(resolve(EX, 'w1b-remainder-ownership.json'), JSON.stringify(remainder, null, 1))

// ── 4. Summary ──────────────────────────────────────────────────────────────
const summary = {
  type: 'PD1_PD2_RULINGS_APPLIED',
  date: '2026-08-18',
  pd2: { status: 'RESOLVED', owners: { structure: 'CH-02', accountEntryExperience: 'CH-10' },
         seamEnumeration: 'CH-02 certification requirement', unblocked: ['W1-C', 'W1-D', 'W1-E'] },
  pd1: { status: 'RESOLVED_FOR_THIS_RECONSTRUCTION_PROGRAMME',
         disposition: 'OUT_OF_CURRENT_RECONSTRUCTION_SCOPE',
         debt: { files: pd1Files.length, sites: pd1Sites, classification: 'FROZEN_BY_RULE' },
         securityBypassCreated: false,
         adminRouteClassificationStillApplies: true },
  g5Reconciliation: { cause: g5.cause, operative: g5.operativeCount, escalated: false },
  debtSeparation: remainder.debtSeparation,
  canonicalUnitsChanged: 0,
  historicalEvidenceRewritten: false,
}
writeFileSync(resolve(EX, 'pd1-pd2-rulings-applied.json'), JSON.stringify(summary, null, 1))

console.log('PD-2 -> CH-02 structure / CH-10 experience; seam enumeration added to CH-02')
console.log('PD-1 -> OUT_OF_CURRENT_RECONSTRUCTION_SCOPE;', pd1Files.length, 'files /', pd1Sites, 'sites FROZEN_BY_RULE')
console.log('executable debt :', remainder.debtSeparation.executable.files, 'files /', remainder.debtSeparation.executable.sites, 'sites')
console.log('frozen by rule  :', remainder.debtSeparation.frozenByRule.files, 'files /', remainder.debtSeparation.frozenByRule.sites, 'sites')
console.log('OK')
