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
const failures = []
const warnings = []

// ── expected universe, from the deterministic pass ──────────────────────────
const issuedF = accounting.rows.filter((r) => r.id.startsWith('F') && r.classification !== 'QUARANTINED_SELF_AUTHORED_ONLY').map((r) => r.id)
const issuedWG = accounting.rows.filter((r) => r.id.startsWith('WG') && r.classification !== 'QUARANTINED_SELF_AUTHORED_ONLY').map((r) => r.id)

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
    wgReconstructed: wgReconstructed.length,
    rcChaptersCovered: rcCovered.length,
    doctrinesIndexed: count(doctrine),
    validationObligations: count(validation),
    protectedBoundaries: count(boundaries),
  },
  provenanceProfile: accounting.findings.byProvenanceStrength,
  warnings,
  failures,
  verdict: failures.length ? 'FAIL' : 'PASS',
  ratified: false,
  note: 'Candidate registers. NOT founder-ratified. Stage 0 may not ratify its own output.',
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
console.log(`\nVERDICT: ${result.verdict}   (ratified: false)\n`)
process.exit(failures.length ? 1 : 0)
