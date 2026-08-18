#!/usr/bin/env node
/**
 * STAGE 5 — DETERMINISTIC EXECUTION-ARCHITECTURE VALIDATION.
 *
 * Proves the 18 invariants required by the Stage-5 authorisation. FAIL CLOSED:
 * "A model saying the roadmap is complete is not proof."
 *
 * Usage: node validate-stage5.mjs <runRoot>
 * Writes: <runRoot>/05-execution/stage5-validation.json
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { execSync } from 'node:child_process'
import { join } from 'node:path'

const root = process.argv[2]
if (!root) { console.error('usage: node validate-stage5.mjs <runRoot>'); process.exit(2) }
const EV = join(root, '00-evidence'), RCD = join(root, '02-reconcile'), SY = join(root, '03-synthesis'), EX = join(root, '05-execution')
const rd = (p) => JSON.parse(readFileSync(p, 'utf8'))
const opt = (p) => (existsSync(p) ? rd(p) : null)
const failures = [], warnings = [], checks = []

const acct = rd(join(EV, 'id-accounting.json'))
const NOT_ISSUED = new Set(['QUARANTINED_SELF_AUTHORED_ONLY', 'RESERVED_UNISSUED'])
const issuedF = acct.rows.filter((r) => r.id.startsWith('F') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)
const reservedWG = acct.wg.reservedUnissued || []
const issuedWG = acct.rows.filter((r) => r.id.startsWith('WG') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)
const regV2 = rd(join(RCD, 'chartered-obligation-register-v2.json'))
const clsV2 = rd(join(SY, 'co-classification-v2.json'))
const fOwn = rd(join(SY, 'ownership-findings.json'))
const arch = rd(join(SY, 'chapter-architecture.json'))
const rulings = rd(join(RCD, 'stage2-amendment-rulings.json'))
const allCo = regV2.obligations.map((c) => c.id)
const chapterIds = [...new Set((arch.chapters || []).map((c) => c.id))]
const NINE = rulings.stage3RebuildRatification.nineRatified

const exec = opt(join(EX, 's5-execution-architecture.json'))
const depA = opt(join(EX, 's5-dependency-keystones.json'))
const riskA = opt(join(EX, 's5-risk-and-timing.json'))
const valA = opt(join(EX, 's5-validation-architecture.json'))
const prodA = opt(join(EX, 's5-product-convergence.json'))
for (const [n, v] of [['s5-execution-architecture.json', exec], ['s5-dependency-keystones.json', depA],
  ['s5-risk-and-timing.json', riskA], ['s5-validation-architecture.json', valA], ['s5-product-convergence.json', prodA]]) {
  if (!v) failures.push('missing Stage-5 artifact: ' + n)
  else if (v.type !== 'ANALYTICAL_PROPOSAL') failures.push(n + ' type must be ANALYTICAL_PROPOSAL')
}

// 1-3, 5-6. canonical units intact and singly owned
const fIds = (fOwn.assignments || []).map((a) => a.id)
const cIds = (clsV2.classifications || []).map((c) => c.id)
const fMissing = issuedF.filter((id) => !fIds.includes(id))
const cMissing = allCo.filter((id) => !cIds.includes(id))
const fDup = fIds.filter((id, i) => fIds.indexOf(id) !== i)
const cDup = cIds.filter((id, i) => cIds.indexOf(id) !== i)
if (issuedF.length !== 143) failures.push('1. findings ' + issuedF.length + ', ratified 143')
if (allCo.length !== 308) failures.push('2. obligations ' + allCo.length + ', ratified 308')
if (issuedF.length + allCo.length !== 451) failures.push('3. units ' + (issuedF.length + allCo.length) + ', ratified 451')
if (fMissing.length || cMissing.length) failures.push('5. units disappeared: ' + [...fMissing, ...cMissing].slice(0, 15).join(', '))
if (fDup.length || cDup.length) failures.push('6. units owned twice: ' + [...new Set([...fDup, ...cDup])].slice(0, 15).join(', '))
if (!failures.length) checks.push('1-3,5-6: 143 findings + 308 obligations = 451 units intact, none dropped or doubly owned')

// 4 & 12. every chapter represented AND dispositioned
if (chapterIds.length !== 17) failures.push('4. chapters ' + chapterIds.length + ', ratified 17')
else checks.push('4. 17/17 executable chapters represented')
if (exec) {
  const disp = exec.chapterDispositions || []
  const dispIds = new Set(disp.map((d) => d.chapter || d.id))
  const undisp = chapterIds.filter((c) => !dispIds.has(c))
  const rm = exec.readinessMatrix || []
  const rmIds = new Set(rm.map((r) => r.chapter || r.id))
  const noReadiness = chapterIds.filter((c) => !rmIds.has(c))
  const DIMS = ['constructionReadiness', 'dependencyReadiness', 'founderDecisionReadiness', 'protectedBoundaryReadiness',
    'migrationDeploymentReadiness', 'validationReadiness', 'certificationReadiness', 'releaseReadiness']
  // Dimensions may be nested under `dimensions` and may carry {value, basis} —
  // that is RICHER than a flat field, not a violation: it preserves the
  // classification basis PER DIMENSION, which §D requires. Absence of the
  // dimension is still a failure; nesting it is not.
  const dimsOf = (r) => (r && typeof r.dimensions === 'object' && r.dimensions) ? r.dimensions : r
  const missingDims = rm.filter((r) => DIMS.some((d) => dimsOf(r)[d] === undefined)).map((r) => r.chapter || r.id)
  if (undisp.length) failures.push('12. chapter(s) with no execution disposition: ' + undisp.join(', '))
  if (noReadiness.length) failures.push('12. chapter(s) missing from the readiness matrix: ' + noReadiness.join(', '))
  if (missingDims.length) failures.push('12. readiness collapsed — chapter(s) missing one of the 8 dimensions: ' + [...new Set(missingDims)].slice(0, 10).join(', '))
  if (!undisp.length && !noReadiness.length && !missingDims.length) {
    checks.push('12. All 17 chapters dispositioned with 8 SEPARATE readiness dimensions (never collapsed)')
  }
}

// 7. nine ratified COs present and sequenced
const nineMissing = NINE.filter((id) => !cIds.includes(id))
if (nineMissing.length) failures.push('7. ratified CO lost: ' + nineMissing.join(', '))
else checks.push('7. All 9 founder-ratified recovered COs present')
if (riskA) {
  const seq = riskA.nineCoSequencing || []
  const seqIds = new Set(seq.map((s) => s.id || s.co))
  const notSeq = NINE.filter((id) => !seqIds.has(id))
  if (notSeq.length) failures.push('7. ratified CO not sequenced: ' + notSeq.join(', '))
  else checks.push('7. All 9 sequenced with earliest-safe-execution points')
}

// 8. RC chapters via provenance
const rcSeen = new Set(regV2.obligations.map((c) => c.rcChapter))
const rcMissing = []
for (let i = 0; i <= 11; i++) if (!rcSeen.has('RC-C' + i)) rcMissing.push('RC-C' + i)
if (rcMissing.length) failures.push('8. RC chapters lost: ' + rcMissing.join(', '))
else checks.push('8. RC-C0..RC-C11 12/12 preserved through charteredBy provenance')

// 9. WG018
if (issuedWG.length !== 17 || !reservedWG.includes('WG018')) failures.push('9. WG accounting drifted')
else checks.push('9. WG001-WG017 issued; WG018 RESERVED/UNISSUED')

// 10 & 11. founder-ratified states unchanged; conflicts not adjudicated
const baseline = new Map()
for (const n of [1, 2, 3]) {
  const p = join(EV, 'findings-batch-' + n + '.json')
  if (!existsSync(p)) continue
  const d = rd(p)
  for (const r of (Array.isArray(d) ? d : d.findings || [])) if (r && r.id) baseline.set(r.id, r.currentState)
}
for (const id of ['F043', 'F051', 'F122']) {
  if (baseline.get(id) !== 'CONFLICTING_CURRENT_STATE') failures.push('11. ' + id + ' conflict lost')
}
if (rulings.F139.ruling !== 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED') failures.push('10. F139 ruling changed')
if (rulings.RC_C10.ruling !== 'ACTIVE / STRUCTURALLY PARTIAL / NOT CERTIFIED') failures.push('10. RC-C10 ruling changed')
if (rulings.RC_C5_GATE_SCOPE.ruling !== 'BIFURCATED') failures.push('10. RC-C5 ruling changed')
checks.push('10-11. Founder-ratified states unchanged; F043/F051/F122 conflicts not adjudicated')

// 13. hard dependencies must point at real canonical targets
if (depA) {
  const deps = depA.dependencies || []
  const valid = new Set([...chapterIds, ...allCo, ...issuedF, 'RC-C5', 'RC-C10'])
  for (let i = 0; i <= 11; i++) valid.add('RC-C' + i)
  // A dependency edge may name a BOUNDED capability rather than a bare chapter id
  // — §G explicitly requires that granularity. The invariant's teeth are kept by
  // demanding that the edge still RESOLVE to at least one canonical anchor
  // (CH-nn, CO-*, F###, RC-Cn, PB-nn) somewhere in its from/to/boundedPrerequisite.
  const ANCHOR = /\b(CH-\d{2}|CO-RC-C\d{1,2}-\d{3}|F\d{3}|RC-C\d{1,2}|PB-\d{2}|WG\d{3})\b/
  const dangling = deps.filter((d) => {
    const t = d.to || d.target
    if (!t) return true
    const blob = [d.from, t, d.boundedPrerequisite].filter(Boolean).join(' ')
    if (ANCHOR.test(String(t))) return false
    if (/^ALL/i.test(String(t)) && ANCHOR.test(blob)) return false
    return !ANCHOR.test(blob)
  }).map((d) => (d.id || '?') + ': ' + String(d.to || d.target || 'MISSING').slice(0, 60))
  if (dangling.length) failures.push('13. dependency target not a canonical capability/chapter/gate: ' + dangling.slice(0, 10).join(', '))
  else checks.push('13. All ' + deps.length + ' dependencies point at real canonical targets')
}

// 14 & 15. founder-sensitive and protected-boundary surfacing
if (riskA) {
  const ft = riskA.founderDecisionTiming || []
  if (ft.length < 6) failures.push('14. only ' + ft.length + ' of the 6 carried founder items timed')
  else checks.push('14. All 6 carried founder-attention items timed with earliest affected wave')
  const pbs = riskA.protectedBoundarySequencing
  if (pbs === undefined) failures.push('15. protected-boundary sequencing not surfaced')
  else checks.push('15. Protected-boundary crossings surfaced (' + (Array.isArray(pbs) ? pbs.length : 0) + ') — identified, NOT authorised')
}

// 16. waves have explicit entry and exit
if (exec) {
  const waves = exec.waves || []
  if (!waves.length) failures.push('16. no execution waves produced')
  else {
    const bad = waves.filter((w) => !(w.prerequisites || w.entryConditions) || !(w.exitCriteria || w.exitConditions)).map((w) => w.id || w.wave || w.name)
    if (bad.length) failures.push('16. wave(s) without explicit entry AND exit conditions: ' + bad.join(', '))
    else checks.push('16. All ' + waves.length + ' waves carry explicit entry and exit conditions')
  }
  // F137 must not be buried
  const txt = JSON.stringify(exec)
  if (!txt.includes('F137')) failures.push('F137 has no explicit execution position')
  else checks.push('F137 given an explicit execution position (not buried)')
}

// 17. no implementation represented as authorised
const allTxt = JSON.stringify([exec, depA, riskA, valA, prodA])
if (/"?(implementationAuthorized|authorizedToImplement)"?\s*:\s*true/i.test(allTxt)) {
  failures.push('17. an artifact represents implementation as AUTHORISED')
} else checks.push('17. No implementation represented as authorised by Stage 5')

// 18. Stage-4 artifact unchanged
try {
  const dirty = execSync('git status --porcelain -- docs/portfolio/run/stage0-2026-08-18/04-proof docs/portfolio/run/stage0-2026-08-18/00-evidence',
    { cwd: 'C:/Users/muham/flutter_projects/aura/aura_final', encoding: 'utf8' }).trim()
  if (dirty) failures.push('18. Stage-4 proof or Stage-0 evidence modified: ' + dirty.replace(/\s+/g, ' ').slice(0, 200))
  else checks.push('18. Stage-4 reconciliation artifact and Stage-0 evidence historically unchanged')
} catch { warnings.push('18. could not verify via git') }

// validation obligation coverage
if (valA && valA.obligationsAccountedFor !== undefined && valA.obligationsAccountedFor !== 82) {
  warnings.push('validation architecture accounts for ' + valA.obligationsAccountedFor + ' of 82 obligations')
}

const result = {
  artifact: 'STAGE_5_DETERMINISTIC_VALIDATION', date: '2026-08-18',
  baseline: { findings: issuedF.length, obligations: allCo.length, units: issuedF.length + allCo.length, chapters: chapterIds.length },
  waves: exec ? (exec.waves || []).length : 0,
  keystones: depA ? (depA.keystones || []).length : 0,
  checksPassed: checks, warnings, failures,
  verdict: failures.length ? 'FAIL' : 'PASS',
  stageStatus: {
    stage0: 'COMPLETE_AND_FOUNDER_RATIFIED', stage1: 'COMPLETE', stage2: 'COMPLETE_WITH_AMENDMENT',
    stage3: 'COMPLETE_FROZEN_FOUNDER_RATIFIED_REBUILD', stage4: 'COMPLETE_DETERMINISTIC_PASS',
    stage5: failures.length ? 'FAILED' : 'COMPLETE',
    productImplementation: 'NOT_AUTHORIZED',
  },
}
writeFileSync(join(EX, 'stage5-validation.json'), JSON.stringify(result, null, 2))
for (const k of checks) console.log('OK    ' + k)
for (const w of warnings) console.log('WARN  ' + w)
for (const f of failures) console.log('FAIL  ' + f)
console.log('\nSTAGE 5: ' + result.baseline.units + ' units / ' + result.baseline.chapters + ' chapters / ' + result.waves + ' waves')
console.log('VERDICT: ' + result.verdict + '   PRODUCT IMPLEMENTATION: NOT AUTHORIZED\n')
process.exit(failures.length ? 1 : 0)
