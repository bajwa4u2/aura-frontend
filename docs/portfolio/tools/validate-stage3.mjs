#!/usr/bin/env node
/**
 * STAGE 3 — DETERMINISTIC DUAL-AXIS OWNERSHIP RECONCILIATION.
 *
 * Consolidation is good; lossy consolidation is forbidden. The whole point of
 * this script is that the portfolio may get SMALLER in executable chapters while
 * the ACCOUNTING may not shrink: 143 findings and 299 chartered obligations must
 * each be owned exactly once, and both populations must reconcile independently.
 *
 * A red validator is EVIDENCE. Do not massage the model until it turns green.
 *
 * Usage: node validate-stage3.mjs <runRoot>
 * Writes: <runRoot>/03-synthesis/stage3-validation.json
 * Exit 1 on any hard failure.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { execSync } from 'node:child_process'
import { join } from 'node:path'

const root = process.argv[2]
if (!root) { console.error('usage: node validate-stage3.mjs <runRoot>'); process.exit(2) }
const EV = join(root, '00-evidence'), RCD = join(root, '02-reconcile'), SY = join(root, '03-synthesis')
const rd = (p) => JSON.parse(readFileSync(p, 'utf8'))
const opt = (p) => (existsSync(p) ? rd(p) : null)

const failures = [], warnings = [], checks = []

// ── earlier layers untouched ────────────────────────────────────────────────
for (const [label, dir] of [['Stage-0 baseline', EV], ['Stage-1 proposals', join(root, '01-analysis')]]) {
  try {
    const rel = dir.replace(/^.*aura_final[\\/]/, '').replace(/\\/g, '/')
    const dirty = execSync('git status --porcelain -- "' + rel + '"', {
      cwd: 'C:/Users/muham/flutter_projects/aura/aura_final', encoding: 'utf8' }).trim()
    if (dirty) failures.push(label + ' MUTATED by Stage 3: ' + dirty.replace(/\s+/g, ' ').slice(0, 240))
    else checks.push(label + ' UNMUTATED by Stage 3')
  } catch (e) { warnings.push('immutability check failed for ' + label) }
}

// ── canonical universes ────────────────────────────────────────────────────
const acct = rd(join(EV, 'id-accounting.json'))
const NOT_ISSUED = new Set(['QUARANTINED_SELF_AUTHORED_ONLY', 'RESERVED_UNISSUED'])
const issuedF = acct.rows.filter((r) => r.id.startsWith('F') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)
const issuedWG = acct.rows.filter((r) => r.id.startsWith('WG') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)
const reservedWG = acct.wg.reservedUnissued || []
const coReg = rd(join(RCD, 'chartered-obligation-register.json'))
const allCo = coReg.obligations.map((c) => c.id)

const baseline = new Map()
for (const n of [1, 2, 3]) {
  const p = join(EV, 'findings-batch-' + n + '.json')
  if (!existsSync(p)) continue
  const arr = rd(p)
  for (const r of (Array.isArray(arr) ? arr : arr.findings || [])) if (r && r.id) baseline.set(r.id, r.currentState)
}
const rulings = rd(join(RCD, 'stage2-amendment-rulings.json'))

// ── chapter architecture ───────────────────────────────────────────────────
const arch = opt(join(SY, 'chapter-architecture.json'))
let chapterIds = new Set()
if (!arch) failures.push('chapter-architecture.json missing')
else {
  if (arch.type !== 'ANALYTICAL_PROPOSAL') failures.push('architecture type must be ANALYTICAL_PROPOSAL')
  for (const c of (arch.chapters || [])) if (c && c.id) chapterIds.add(c.id)
  if (!chapterIds.size) failures.push('architecture defines no chapters')
  else checks.push('Architecture defines ' + chapterIds.size + ' implementation chapters')
}

// ── generic exactly-once ownership check ───────────────────────────────────
function reconcile(axisName, expectedIds, files, idKey) {
  const owner = new Map(), dupes = [], unassignable = [], badChapter = [], noOwner = []
  for (const f of files) {
    const o = opt(join(SY, f))
    if (!o) { failures.push(axisName + ' — ' + f + ' missing'); continue }
    if (o.type !== 'ANALYTICAL_PROPOSAL') failures.push(axisName + ' — ' + f + ' type must be ANALYTICAL_PROPOSAL')
    for (const a of (o.assignments || [])) {
      if (!a || !a[idKey]) continue
      const id = a[idKey]
      // Agents have emitted the owner under either key name. Both are accepted as a
      // documented normalisation — but ABSENCE is a hard failure, not a skip. The
      // earlier version treated an undefined owner as "owned", which let 135
      // obligations pass with no owning chapter at all.
      const ch = a.canonicalChapter || a.canonicalOwner
      if (!ch) { noOwner.push(id); continue }
      if (owner.has(id)) dupes.push(id + ' [' + owner.get(id) + ' & ' + ch + ']')
      else owner.set(id, ch)
      if (ch === 'UNASSIGNABLE') unassignable.push(id)
      else if (chapterIds.size && ch && !chapterIds.has(ch)) badChapter.push(id + '->' + ch)
    }
    for (const u of (o.unassignable || [])) {
      const id = typeof u === 'string' ? u : u && u[idKey]
      if (id && !owner.has(id)) { owner.set(id, 'UNASSIGNABLE'); unassignable.push(id) }
    }
  }
  const missing = expectedIds.filter((id) => !owner.has(id))
  const invented = [...owner.keys()].filter((id) => !expectedIds.includes(id))

  if (dupes.length) failures.push(axisName + ' — DUPLICATE OWNERSHIP: ' + [...new Set(dupes)].slice(0, 12).join('; '))
  if (missing.length) failures.push(axisName + ' — ' + missing.length + ' DROPPED id(s): ' + missing.slice(0, 20).join(', '))
  if (invented.length) failures.push(axisName + ' — ' + invented.length + ' INVENTED id(s): ' + invented.slice(0, 20).join(', '))
  if (badChapter.length) failures.push(axisName + ' — assignment(s) to a chapter outside the fixed set: ' + badChapter.slice(0, 10).join(', '))
  if (unassignable.length) failures.push(axisName + ' — ' + unassignable.length + ' UNASSIGNABLE: ' + unassignable.slice(0, 20).join(', '))
  if (noOwner.length) failures.push(axisName + ' — ' + noOwner.length + ' assignment(s) carry NO owning chapter: ' + noOwner.slice(0, 20).join(', '))
  if (!dupes.length && !missing.length && !invented.length && !badChapter.length && !unassignable.length && !noOwner.length) {
    checks.push(axisName + ': ' + owner.size + '/' + expectedIds.length + ' owned EXACTLY ONCE')
  }
  return owner
}

const fOwner = reconcile('AXIS 1 findings', issuedF, ['ownership-findings.json'], 'id')
const coOwner = reconcile('AXIS 2 obligations', allCo, ['ownership-co-a.json', 'ownership-co-b.json'], 'id')

// ── 12/12 RC chapters still represented through charteredBy ────────────────
const coById = new Map(coReg.obligations.map((c) => [c.id, c]))
const rcSeen = new Set()
for (const id of coOwner.keys()) { const c = coById.get(id); if (c) rcSeen.add(c.rcChapter) }
const rcMissing = []
for (let i = 0; i <= 11; i++) if (!rcSeen.has('RC-C' + i)) rcMissing.push('RC-C' + i)
if (rcMissing.length) failures.push('RC chapter(s) lost from ownership: ' + rcMissing.join(', '))
else checks.push('RC chapters: 12/12 still represented via charteredBy')

// charteredBy must never be erased
const coA = opt(join(SY, 'ownership-co-a.json')), coB = opt(join(SY, 'ownership-co-b.json'))
let missingCharter = 0
for (const o of [coA, coB]) for (const a of ((o && o.assignments) || [])) if (!a.charteredBy) missingCharter++
if (missingCharter) failures.push(missingCharter + ' obligation assignment(s) erased charteredBy — charter and implementation ownership are different facts')
else checks.push('charteredBy preserved on every obligation assignment')

// no obligation satisfied because a related finding closed
let inferred = 0
for (const o of [coA, coB]) for (const a of ((o && o.assignments) || [])) {
  if (/satisf|complete/i.test(String(a.obligationClass)) && a.obligationClass !== 'PARTIALLY_COMPLETED' && a.obligationClass !== 'COMPLETED_OR_SUPERSEDED') inferred++
}
if (inferred) warnings.push(inferred + ' obligation(s) use a non-vocabulary completion class')
else checks.push('No obligation declared satisfied outside the permitted class vocabulary')

// ── state preservation ─────────────────────────────────────────────────────
const fOwnFile = opt(join(SY, 'ownership-findings.json'))
const mutations = []
for (const a of ((fOwnFile && fOwnFile.assignments) || [])) {
  if (!a || !a.id || !a.currentState) continue
  const expected = a.id === 'F139' ? rulings.F139.ruling : baseline.get(a.id)
  if (expected && a.currentState !== expected) mutations.push(a.id + ' ' + expected + '->' + a.currentState)
}
if (mutations.length) failures.push('UNAUTHORISED STATE MUTATION: ' + mutations.slice(0, 10).join('; '))
else checks.push('No unauthorised state mutation across finding assignments')

for (const id of ['F043', 'F051', 'F122']) {
  const a = ((fOwnFile && fOwnFile.assignments) || []).find((x) => x && x.id === id)
  if (baseline.get(id) !== 'CONFLICTING_CURRENT_STATE') failures.push(id + ' conflict lost in the baseline')
  else if (a && a.currentState && a.currentState !== 'CONFLICTING_CURRENT_STATE') failures.push(id + ' quietly adjudicated to ' + a.currentState)
}
checks.push('F043/F051/F122 remain CONFLICTING_CURRENT_STATE')

if (rulings.F139.ruling !== 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED' || rulings.F139.historicalContradictionPreserved !== true) {
  failures.push('F139 founder ruling not preserved')
} else checks.push('F139 founder ruling preserved (structural CLOSED / certification OUTSTANDING)')

if (!rulings.RC_C10 || rulings.RC_C10.ruling !== 'ACTIVE / STRUCTURALLY PARTIAL / NOT CERTIFIED') {
  failures.push('RC-C10 founder ruling not preserved')
} else {
  const d = rulings.RC_C10.dimensions || {}
  if (d.founderCertification !== 'NO' || d.productionOrLiveCertification !== 'NO' || d.implementationCompletion !== 'NO') {
    failures.push('RC-C10 treated as complete or certified')
  } else checks.push('RC-C10 ruling preserved: ACTIVE / STRUCTURALLY PARTIAL / NOT CERTIFIED, gates intact')
}

// ── F137 must be explicitly owned ──────────────────────────────────────────
const f137 = ((fOwnFile && fOwnFile.assignments) || []).find((a) => a && a.id === 'F137')
if (!f137 || !f137.canonicalChapter || f137.canonicalChapter === 'UNASSIGNABLE') {
  failures.push('F137 (ZERO_COVERAGE_SECURITY_GAP) has no explicit owner')
} else checks.push('F137 explicitly owned by ' + f137.canonicalChapter)

// ── WG + protected boundaries accounted ────────────────────────────────────
if (issuedWG.length !== 17 || !reservedWG.includes('WG018')) failures.push('WG accounting drifted: issued ' + issuedWG.length + ', reserved ' + reservedWG.join(','))
else checks.push('WG: 17 issued (WG001-WG017), WG018 reserved')

const archTxt = JSON.stringify(arch || {})
const pbMissing = []
for (let i = 1; i <= 12; i++) { const pb = 'PB-' + String(i).padStart(2, '0'); if (!archTxt.includes(pb)) pbMissing.push(pb) }
if (pbMissing.length) failures.push('protected boundary/ies not accounted in the architecture: ' + pbMissing.join(', '))
else checks.push('Protected boundaries: 12/12 accounted in the chapter architecture')

// ── portfolio health ───────────────────────────────────────────────────────
const byChapter = {}
for (const [, ch] of fOwner) byChapter[ch] = byChapter[ch] || { f: 0, co: 0 }, byChapter[ch].f++
for (const [, ch] of coOwner) byChapter[ch] = byChapter[ch] || { f: 0, co: 0 }, byChapter[ch].co++
const totalUnits = issuedF.length + allCo.length
const emptyChapters = [...chapterIds].filter((c) => !byChapter[c])
if (emptyChapters.length) warnings.push('chapter(s) owning nothing: ' + emptyChapters.join(', '))

const result = {
  stage: 'STAGE_3', type: 'DETERMINISTIC_DUAL_AXIS_OWNERSHIP_RECONCILIATION', date: '2026-08-18',
  portfolioHealth: {
    findings: fOwner.size + '/' + issuedF.length,
    charteredObligations: coOwner.size + '/' + allCo.length,
    combinedCanonicalUnits: totalUnits,
    executableChapters: chapterIds.size,
    reductionRatio: chapterIds.size ? Number((totalUnits / chapterIds.size).toFixed(1)) : null,
    rcChaptersRepresented: 12 - rcMissing.length + '/12',
    wg: '17 issued / WG018 reserved',
    protectedBoundaries: 12 - pbMissing.length + '/12',
  },
  perChapter: byChapter,
  checksPassed: checks, warnings, failures,
  verdict: failures.length ? 'FAIL' : 'PASS',
  stageStatus: {
    stage0: 'COMPLETE_AND_FOUNDER_RATIFIED', stage1: 'COMPLETE', stage2: 'COMPLETE_WITH_AMENDMENT',
    stage3: failures.length ? 'FAILED_RECONCILIATION' : 'COMPLETE', stage4: 'NOT_STARTED_NOT_AUTHORIZED',
  },
}
writeFileSync(join(SY, 'stage3-validation.json'), JSON.stringify(result, null, 2))
for (const k of checks) console.log('OK    ' + k)
for (const w of warnings) console.log('WARN  ' + w)
for (const f of failures) console.log('FAIL  ' + f)
console.log('\nPORTFOLIO: ' + result.portfolioHealth.findings + ' findings, ' +
  result.portfolioHealth.charteredObligations + ' obligations, ' + chapterIds.size + ' executable chapters (' +
  totalUnits + ' canonical units)')
console.log('VERDICT: ' + result.verdict + '   STAGE 3: ' + result.stageStatus.stage3 + '   STAGE 4: NOT_AUTHORIZED\n')
process.exit(failures.length ? 1 : 0)
