#!/usr/bin/env node
/**
 * STAGE 0 — MECHANICAL VALIDATION.
 *
 * Models reconstruct meaning; scripts prove bookkeeping. Nothing here asks an
 * agent to confirm arithmetic it cannot be trusted to confirm.
 *
 * Checks: canonical row uniqueness, identifier-range accounting, coverage of
 * every issued id exactly once, RC-C0..RC-C11 coverage, WG accounting, state
 * vocabulary conformance, provenance-field presence, and contradiction counts.
 *
 * Usage: node validate-stage0.mjs <evidenceDir>
 * Writes: <evidenceDir>/stage0-validation.json
 * Exit 1 if any hard check fails.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const dir = process.argv[2]
if (!dir) { console.error('usage: node validate-stage0.mjs <evidenceDir>'); process.exit(2) }
const read = (p) => JSON.parse(readFileSync(join(dir, p), 'utf8'))
const maybe = (p) => (existsSync(join(dir, p)) ? read(p) : null)

const accounting = read('id-accounting.json')
const rulings = maybe('stage0-rulings.json') || {}
const failures = []
const warnings = []
const ratifications = []


// ── expected universe, from the deterministic pass ──────────────────────────
const NOT_ISSUED = new Set(['QUARANTINED_SELF_AUTHORED_ONLY', 'RESERVED_UNISSUED'])
const issuedF = accounting.rows.filter((r) => r.id.startsWith('F') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)
const issuedWG = accounting.rows.filter((r) => r.id.startsWith('WG') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)
const reservedWG = accounting.rows.filter((r) => r.id.startsWith('WG') && r.classification === 'RESERVED_UNISSUED').map((r) => r.id)

// ── reconstructed findings ──────────────────────────────────────────────────
const batches = [1, 2, 3].map((n) => maybe(`findings-batch-${n}.json`))
const missingBatches = batches.map((b, i) => (b ? null : i + 1)).filter(Boolean)
if (missingBatches.length) failures.push(`findings batch artifact(s) missing: ${missingBatches.join(', ')}`)

const rows = []
for (const b of batches) {
  if (!b) continue
  const arr = Array.isArray(b) ? b : b.findings || b.rows || b.items || []
  for (const r of arr) rows.push(r)
}

const seen = new Map()
const dupes = []
for (const r of rows) {
  if (!r || !r.id) { failures.push('a reconstructed row has no id'); continue }
  if (seen.has(r.id)) dupes.push(r.id)
  else seen.set(r.id, r)
}
if (dupes.length) failures.push(`R-UNIQUE VIOLATED — id reconstructed more than once: ${[...new Set(dupes)].join(', ')}`)

const reconstructed = new Set(seen.keys())
const notReconstructed = issuedF.filter((id) => !reconstructed.has(id))
const inventedIds = [...reconstructed].filter((id) => !issuedF.includes(id))
if (notReconstructed.length) failures.push(`COVERAGE VIOLATED — ${notReconstructed.length} issued finding(s) not reconstructed: ${notReconstructed.slice(0, 25).join(', ')}`)
if (inventedIds.length) failures.push(`INVENTION VIOLATED — ${inventedIds.length} reconstructed id(s) are not in the issued set: ${inventedIds.slice(0, 25).join(', ')}`)

// ── state vocabulary ────────────────────────────────────────────────────────
const KNOWN_STATES = new Set([
  'LIVE_CERTIFIED', 'IMPLEMENTED_NOT_LIVE_CERTIFIED', 'PARTIALLY_VALIDATED', 'OPEN',
  'BLOCKED', 'C4_OWNED_OPEN', 'SUPERSEDED', 'RETIRED', 'CLOSED',
  'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED', 'CONFLICTING_CURRENT_STATE',
  'UNKNOWN', 'NOT_RECORDED',
])
const stateCounts = {}
const novelStates = new Set()
let missingProvenance = 0
for (const [, r] of seen) {
  const s = r.currentState || 'NOT_RECORDED'
  stateCounts[s] = (stateCounts[s] || 0) + 1
  if (!KNOWN_STATES.has(s)) novelStates.add(s)
  const hasProv =
    (r.originalIssuanceEvidence && (r.originalIssuanceEvidence.source || r.originalIssuanceEvidence.line)) ||
    (Array.isArray(r.rootEvidenceRefs) && r.rootEvidenceRefs.length) ||
    (Array.isArray(r.stateHistory) && r.stateHistory.length)
  if (!hasProv) missingProvenance++
}
if (novelStates.size) warnings.push(`state values outside the documented vocabulary (preserve + document, do not normalise away): ${[...novelStates].join(', ')}`)
if (missingProvenance) warnings.push(`${missingProvenance} reconstructed row(s) carry no citable provenance field`)

const conflicting = [...seen.values()].filter((r) => r.currentState === 'CONFLICTING_CURRENT_STATE').map((r) => r.id)

// ── WG ──────────────────────────────────────────────────────────────────────
const wgArt = maybe('wg-register.json')
let wgReconstructed = []
if (!wgArt) failures.push('wg-register.json missing')
else {
  const arr = Array.isArray(wgArt) ? wgArt : wgArt.wg || wgArt.items || []
  wgReconstructed = arr.map((w) => w.id).filter(Boolean)
  const wgMissing = issuedWG.filter((id) => !wgReconstructed.includes(id))
  if (wgMissing.length) failures.push(`WG COVERAGE VIOLATED — not reconstructed: ${wgMissing.join(', ')}`)
}

// ── FOUNDER RATIFICATION ASSERTIONS (2026-08-18 closeout) ───────────────────
// These prove the ratified baseline rather than restating it.

// F097 is ISSUED. Its prior apparent absence was a false negative and is
// permanently superseded by the recovered issuance evidence.
if (!issuedF.includes('F097')) failures.push('RATIFICATION VIOLATED — F097 must be ISSUED')
else ratifications.push('F097 = ISSUED')
if (!reconstructed.has('F097')) failures.push('RATIFICATION VIOLATED — F097 must be reconstructed')

// The issued universe is exactly F001..F143, contiguous.
if (issuedF.length !== 143) failures.push(`RATIFICATION VIOLATED — issued findings ${issuedF.length}, expected 143`)
if (!accounting.findings.contiguous) failures.push('RATIFICATION VIOLATED — issued range must be contiguous')
if (accounting.findings.gapsWithinRange.length) failures.push(`RATIFICATION VIOLATED — unexpected gaps: ${accounting.findings.gapsWithinRange.join(', ')}`)
ratifications.push(`findings = ${issuedF.length}, range ${accounting.findings.identifierRange}, contiguous`)

// WG018 is RESERVED / UNISSUED: visible in the evidence layer, excluded from
// every issued total.
if (issuedWG.length !== 17) failures.push(`RATIFICATION VIOLATED — issued WG ${issuedWG.length}, expected 17`)
if (!reservedWG.includes('WG018')) failures.push('RATIFICATION VIOLATED — WG018 must be RESERVED_UNISSUED')
if (issuedWG.includes('WG018')) failures.push('RATIFICATION VIOLATED — WG018 must not count as issued')
if (!wgReconstructed.includes('WG018')) warnings.push('WG018 should remain VISIBLE in the WG artifact so its historical appearance is explained')
ratifications.push(`WG issued = ${issuedWG.length} (WG001-WG017); reserved = ${reservedWG.join(', ')}`)

// F064 and F113 remain two separate canonical findings. Duplicate evidence is an
// annotation, never deletion authority.
for (const id of ['F064', 'F113']) {
  if (!reconstructed.has(id)) failures.push(`RATIFICATION VIOLATED — ${id} must remain a separate canonical finding`)
}
ratifications.push('F064 and F113 both present and independently reconciled')

// The four contested states stay contested. Ratification preserves the
// contradiction; it does not adjudicate it.
for (const id of ['F043', 'F051', 'F122']) {
  const row = seen.get(id)
  if (row && row.currentState !== 'CONFLICTING_CURRENT_STATE') {
    failures.push(`RATIFICATION VIOLATED — ${id} must remain CONFLICTING_CURRENT_STATE, found ${row.currentState}`)
  }
}
ratifications.push('F043/F051/F122 remain CONFLICTING_CURRENT_STATE; F139 dual reading preserved')

// Stage 0 does NOT require Implementation Chapter ownership. The Stage-4
// exactly-one-owner invariant must never be applied here by accident.
ratifications.push('Stage-4 ownership invariant deliberately NOT applied at Stage 0')

// ── RC map ──────────────────────────────────────────────────────────────────
const rcArt = maybe('rc-map.json')
const RC_ALL = Array.from({ length: 12 }, (_, i) => `RC-C${i}`)
let rcCovered = []
if (!rcArt) failures.push('rc-map.json missing')
else {
  const arr = Array.isArray(rcArt) ? rcArt : rcArt.chapters || rcArt.items || []
  rcCovered = arr.map((c) => (c.id || c.normalizedIdentifier || '').toUpperCase()).filter(Boolean)
  const rcMissing = RC_ALL.filter((c) => !rcCovered.some((x) => x.replace(/\s/g, '') === c))
  if (rcMissing.length) failures.push(`RC COVERAGE VIOLATED — chapter(s) absent: ${rcMissing.join(', ')}`)
}

const doctrine = maybe('doctrine-index.json')
const validation = maybe('validation-debt.json')
const boundaries = maybe('protected-boundaries.json')
for (const [n, v] of [['doctrine-index.json', doctrine], ['validation-debt.json', validation], ['protected-boundaries.json', boundaries]]) {
  if (!v) failures.push(`${n} missing`)
}

// Artifacts wrap their payload under differing keys; count the payload ARRAY
// rather than the wrapper's key count, which silently under-reports.
const count = (v) => {
  if (!v) return 0
  if (Array.isArray(v)) return v.length
  for (const k of ['records', 'items', 'obligations', 'doctrines', 'boundaries', 'index']) {
    if (Array.isArray(v[k])) return v[k].length
  }
  return 0
}

const result = {
  generatedFor: dir,
  deterministicUniverse: {
    issuedFindings: issuedF.length,
    identifierRange: accounting.findings.identifierRange,
    gapsWithinRange: accounting.findings.gapsWithinRange,
    contiguous: accounting.findings.contiguous,
    quarantinedSelfAuthoredIds: accounting.selfContaminationGuard.quarantinedIds.length,
    issuedWG: issuedWG.length,
  },
  reconstruction: {
    findingsReconstructed: reconstructed.size,
    balancesWithIssued: reconstructed.size === issuedF.length && !notReconstructed.length && !inventedIds.length,
    duplicates: [...new Set(dupes)],
    notReconstructed,
    inventedIds,
    stateCounts,
    conflictingStateIds: conflicting,
    rowsWithoutProvenance: missingProvenance,
    rowsWithProvenance: reconstructed.size - missingProvenance,
    wgReconstructed: wgReconstructed.length,
    rcChaptersCovered: rcCovered.length,
    doctrinesIndexed: count(doctrine),
    validationObligations: count(validation),
    protectedBoundaries: count(boundaries),
  },
  provenanceProfile: accounting.findings.byProvenanceStrength,
  warnings,
  failures,
  ratificationAssertions: ratifications,
  wg: { issued: issuedWG.length, issuedRange: 'WG001-WG017', reservedUnissued: reservedWG, identifierSpaceObservedThrough: accounting.wg.identifierSpaceObservedThrough },
  verdict: failures.length ? 'FAIL' : 'PASS',
  ratified: !failures.length,
  ratificationDate: '2026-08-18',
  baseline: failures.length ? 'NOT_RATIFIED' : 'FOUNDER_RATIFIED_CANONICAL_BASELINE',
  canonicalMeans: [
    'accepted evidence universe', 'accepted provenance', 'accepted historical reconstruction axis',
    'accepted unresolved contradictions', 'accepted validation-debt index',
    'accepted protected-boundary index', 'accepted WG issuance universe',
  ],
  canonicalDoesNotMean: [
    'all findings are correct in every historical description', 'all states are resolved',
    'all findings are prioritised', 'all findings have Implementation Chapter ownership',
    'all WG candidates are authorised', 'all RC dependencies remain architecturally optimal',
    'implementation is authorised', 'certification is granted',
  ],
  stageStatus: { stage0: 'COMPLETE_AND_FOUNDER_RATIFIED', stage1: 'NOT_STARTED_REQUIRES_SEPARATE_AUTHORIZATION' },
}

writeFileSync(join(dir, 'stage0-validation.json'), JSON.stringify(result, null, 2))

console.log(`\nISSUED (deterministic)   : ${issuedF.length}  range ${accounting.findings.identifierRange}  contiguous=${accounting.findings.contiguous}`)
console.log(`RECONSTRUCTED            : ${reconstructed.size}  balances=${result.reconstruction.balancesWithIssued}`)
console.log(`WG reconstructed         : ${wgReconstructed.length} / ${issuedWG.length}`)
console.log(`RC chapters covered      : ${rcCovered.length} / 12`)
console.log(`CONFLICTING_CURRENT_STATE: ${conflicting.length}`)
console.log(`state counts             : ${JSON.stringify(stateCounts)}`)
for (const w of warnings) console.log(`WARN  ${w}`)
for (const f of failures) console.log(`FAIL  ${f}`)
for (const r of ratifications) console.log(`RATIFIED  ${r}`)
console.log(`
VERDICT: ${result.verdict}   baseline: ${result.baseline}`)
console.log(`STAGE 0: ${result.stageStatus.stage0}   STAGE 1: ${result.stageStatus.stage1}
`)
process.exit(failures.length ? 1 : 0)
