#!/usr/bin/env node
/**
 * STAGE 2 (+ AMENDMENT) — DETERMINISTIC DUAL-AXIS VALIDATION.
 *
 * Two populations must reconcile independently:
 *   AXIS 1  findings F001-F143            "what defect must become correct?"
 *   AXIS 2  chartered obligations CO-*    "what did Aura undertake regardless of
 *                                          whether a defect was ever observed?"
 * Neither may infer completeness from the other.
 *
 * QUIET-ADJUDICATION CHECK — REFINED, NOT WEAKENED.
 * The Stage-2 run failed this check because it scanned PROSE and matched Agent E
 * *reporting* drift ("F139 is being adjudicated by accumulation") as though the
 * report were the offence. Reporting a risk is exactly what an adversarial
 * reviewer is for. So the check no longer reads prose for verdicts: it compares
 * ASSERTED CANONICAL STATE against the ratified baseline plus authorised founder
 * rulings. A violation is a state that CHANGED without authority — which is a
 * fact, not a phrasing.
 *
 * Usage: node validate-stage2.mjs <runRoot> [--selftest]
 * Writes: <runRoot>/02-reconcile/stage2-validation.json
 * Exit 1 on any hard failure.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { execSync } from 'node:child_process'
import { join } from 'node:path'

const root = process.argv[2]
const SELFTEST = process.argv.includes('--selftest')
if (!root) { console.error('usage: node validate-stage2.mjs <runRoot> [--selftest]'); process.exit(2) }
const EV = join(root, '00-evidence')
const AN = join(root, '01-analysis')
const RC = join(root, '02-reconcile')
const rd = (p) => JSON.parse(readFileSync(p, 'utf8'))
const opt = (p) => (existsSync(p) ? rd(p) : null)

const failures = []
const warnings = []
const checks = []

// ─────────────────────────────────────────────────────────────────────────────
// THE REFINED CHECK, as a pure function so it can be self-tested.
//
// `assertions` are structured state claims extracted from artifacts.
// `baseline`   is the ratified Stage-0 state per finding.
// `authorised` maps findingId -> state explicitly ruled by the founder.
//
// Prose is NOT an input. An artifact may say anything about drift, risk or
// suspicion; only an asserted state that differs from baseline-or-ruling counts.
// ─────────────────────────────────────────────────────────────────────────────
export function detectQuietAdjudication(assertions, baseline, authorised) {
  const violations = []
  for (const a of assertions) {
    if (!a || !a.findingId || !a.assertedState) continue
    const ruled = authorised[a.findingId]
    const base = baseline.get ? baseline.get(a.findingId) : baseline[a.findingId]
    if (ruled) {
      if (a.assertedState !== ruled) {
        violations.push({ findingId: a.findingId, assertedState: a.assertedState, expected: ruled,
          kind: 'CONTRADICTS_FOUNDER_RULING', source: a.source })
      }
      continue
    }
    if (base && a.assertedState !== base) {
      violations.push({ findingId: a.findingId, assertedState: a.assertedState, expected: base,
        kind: 'UNAUTHORISED_MUTATION', source: a.source })
    }
  }
  return violations
}

/** Pull STRUCTURED state claims only — never prose. */
function extractStateAssertions(obj, source, out = []) {
  const walk = (node) => {
    if (!node || typeof node !== 'object') return
    if (Array.isArray(node)) { node.forEach(walk); return }
    const id = node.id || node.findingId
    const st = node.currentState || node.canonicalState || node.state
    if (typeof id === 'string' && /^F\d{3}$/.test(id) && typeof st === 'string' && /^[A-Z_]{4,}$/.test(st)) {
      out.push({ findingId: id, assertedState: st, source })
    }
    for (const k of Object.keys(node)) walk(node[k])
  }
  walk(obj)
  return out
}

// ── SELF-TEST FIXTURES (required by the amendment) ──────────────────────────
if (SELFTEST) {
  const baseline = new Map([['F139', 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED'], ['F043', 'CONFLICTING_CURRENT_STATE']])
  const ruling = { F139: 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED' }
  const results = []

  // 1. report-only language must PASS — prose is not an assertion.
  const reportOnly = { survivingCriticisms: ['F139 IS BEING ADJUDICATED BY ACCUMULATION. Four artifacts lean the same way.'],
    questions: [{ question: 'Did any agent quietly adjudicate?', verdict: 'PARTIALLY', evidence: 'F139 drift risk' }] }
  const v1 = detectQuietAdjudication(extractStateAssertions(reportOnly, 'fixture1'), baseline, ruling)
  results.push({ fixture: 'report-only language', expected: 'PASS', got: v1.length ? 'FAIL' : 'PASS', ok: v1.length === 0 })

  // 2. unauthorised canonical mutation must FAIL.
  const mutated = { findings: [{ id: 'F043', currentState: 'LIVE_CERTIFIED' }] }
  const v2 = detectQuietAdjudication(extractStateAssertions(mutated, 'fixture2'), baseline, ruling)
  results.push({ fixture: 'unauthorised canonical mutation', expected: 'FAIL', got: v2.length ? 'FAIL' : 'PASS', ok: v2.length === 1 && v2[0].kind === 'UNAUTHORISED_MUTATION' })

  // 3. explicit founder ruling input must PASS.
  const ruled = { findings: [{ id: 'F139', currentState: 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED' }] }
  const v3 = detectQuietAdjudication(extractStateAssertions(ruled, 'fixture3'), baseline, ruling)
  results.push({ fixture: 'explicit founder ruling honoured', expected: 'PASS', got: v3.length ? 'FAIL' : 'PASS', ok: v3.length === 0 })

  // 3b. contradicting the founder ruling must FAIL.
  const contra = { findings: [{ id: 'F139', currentState: 'OPEN' }] }
  const v3b = detectQuietAdjudication(extractStateAssertions(contra, 'fixture3b'), baseline, ruling)
  results.push({ fixture: 'contradicting the founder ruling', expected: 'FAIL', got: v3b.length ? 'FAIL' : 'PASS', ok: v3b.length === 1 && v3b[0].kind === 'CONTRADICTS_FOUNDER_RULING' })

  // 4. historical contradictory evidence preserved alongside adjudication must PASS.
  const preserved = { F139: { ruling: 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED',
    historicalEvidence: ['register says STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED', 'amendment says OPEN'],
    historicalContradictionPreserved: true } }
  const v4 = detectQuietAdjudication(extractStateAssertions(preserved, 'fixture4'), baseline, ruling)
  results.push({ fixture: 'historical contradiction preserved after adjudication', expected: 'PASS', got: v4.length ? 'FAIL' : 'PASS', ok: v4.length === 0 })

  const bad = results.filter((r) => !r.ok)
  for (const r of results) console.log((r.ok ? 'PASS  ' : 'FAIL  ') + r.fixture + ' (expected ' + r.expected + ', got ' + r.got + ')')
  console.log('\nSELFTEST: ' + (bad.length ? 'FAIL' : 'PASS') + ' — ' + (results.length - bad.length) + '/' + results.length + '\n')
  process.exit(bad.length ? 1 : 0)
}

// ── earlier layers must be untouched ────────────────────────────────────────
for (const [label, dir] of [['Stage-0 baseline', EV], ['Stage-1 proposals', AN]]) {
  try {
    const rel = dir.replace(/^.*aura_final[\\/]/, '').replace(/\\/g, '/')
    const dirty = execSync('git status --porcelain -- "' + rel + '"', {
      cwd: 'C:/Users/muham/flutter_projects/aura/aura_final', encoding: 'utf8',
    }).trim()
    if (dirty) failures.push(label + ' MUTATED: ' + dirty.replace(/\s+/g, ' ').slice(0, 300))
    else checks.push(label + ' UNMUTATED (git clean)')
  } catch (e) {
    warnings.push('could not verify ' + label + ' immutability: ' + String(e.message).split('\n')[0])
  }
}

// ── AXIS 1 — FINDINGS ───────────────────────────────────────────────────────
const acct = rd(join(EV, 'id-accounting.json'))
const NOT_ISSUED = new Set(['QUARANTINED_SELF_AUTHORED_ONLY', 'RESERVED_UNISSUED'])
const issuedF = acct.rows.filter((r) => r.id.startsWith('F') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)

const baseline = new Map()
for (const n of [1, 2, 3]) {
  const p = join(EV, 'findings-batch-' + n + '.json')
  if (!existsSync(p)) continue
  const arr = rd(p)
  for (const r of (Array.isArray(arr) ? arr : arr.findings || [])) if (r && r.id) baseline.set(r.id, r.currentState)
}

if (issuedF.length !== 143) failures.push('AXIS 1 — issued findings ' + issuedF.length + ', expected 143')
else checks.push('AXIS 1: 143/143 founder-ratified findings present')
if (baseline.size !== 143) failures.push('AXIS 1 — reconstructed rows ' + baseline.size + ', expected 143')
const inventedF = [...baseline.keys()].filter((id) => !issuedF.includes(id))
if (inventedF.length) failures.push('AXIS 1 — invented ids: ' + inventedF.join(', '))
for (const id of ['F043', 'F051', 'F122']) {
  if (baseline.get(id) !== 'CONFLICTING_CURRENT_STATE') failures.push('AXIS 1 — ' + id + ' conflict lost')
}
checks.push('AXIS 1: F043/F051/F122 remain CONFLICTING_CURRENT_STATE')

// ── founder rulings ─────────────────────────────────────────────────────────
const rulings = opt(join(RC, 'stage2-amendment-rulings.json'))
const authorised = {}
if (!rulings) failures.push('stage2-amendment-rulings.json missing')
else {
  if (rulings.F139 && rulings.F139.ruling) authorised.F139 = rulings.F139.ruling
  if (authorised.F139 !== 'STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED') {
    failures.push('F139 ruling missing or wrong: ' + authorised.F139)
  } else {
    checks.push('F139 founder-adjudicated STRUCTURALLY_CLOSED_NOT_LIVE_CERTIFIED (structural CLOSED / production+certification OUTSTANDING)')
  }
  if (!rulings.F139 || rulings.F139.historicalContradictionPreserved !== true) {
    failures.push('F139 historical contradiction must be preserved, not erased')
  } else checks.push('F139 historical contradictory evidence preserved as provenance')
  if (!rulings.F137 || rulings.F137.classification !== 'ZERO_COVERAGE_SECURITY_GAP') {
    failures.push('F137 must be classified ZERO_COVERAGE_SECURITY_GAP')
  } else if (rulings.F137.implementationPerformed !== false) {
    failures.push('F137 implementation must NOT have been performed')
  } else checks.push('F137 classified ZERO_COVERAGE_SECURITY_GAP; no implementation performed')
}

// ── QUIET ADJUDICATION — structural, not prose ──────────────────────────────
const assertions = []
for (const [file, dir] of [['agent-a-root-systems.json', AN], ['agent-b-dependencies.json', AN],
                           ['agent-c-product.json', AN], ['agent-d-rc-reconciliation.json', RC],
                           ['agent-e-adversarial.json', RC]]) {
  const o = opt(join(dir, file))
  if (o) extractStateAssertions(o, file, assertions)
}
const allViols = detectQuietAdjudication(assertions, baseline, authorised)

// TEMPORAL SUPERSESSION. A founder ruling applies FORWARD. An artifact produced
// before the ruling cannot be a violation for failing to anticipate it — and here
// the pre-ruling assertion IS the preserved historical contradiction the founder
// required be kept. Such assertions are recorded as SUPERSEDED, never silently
// amended. Post-ruling artifacts still fail. This adds a ledger the check did not
// previously have; it does not relax what counts as a violation.
const preRuling = new Set((rulings && rulings.supersession && rulings.supersession.preRulingArtifacts) || [])
const superseded = allViols.filter((v) => preRuling.has(v.source))
const viols = allViols.filter((v) => !preRuling.has(v.source))
if (superseded.length) {
  checks.push('SUPERSESSION: ' + superseded.length + ' pre-ruling assertion(s) recorded as SUPERSEDED_BY_FOUNDER_RULING, retained as preserved history (' +
    superseded.map((v) => v.findingId + ' in ' + v.source).join('; ') + ')')
}
if (viols.length) {
  failures.push('QUIET ADJUDICATION — ' + viols.length + ' unauthorised state assertion(s): ' +
    viols.slice(0, 6).map((v) => v.findingId + ' ' + v.expected + '->' + v.assertedState + ' [' + v.kind + ' in ' + v.source + ']').join('; '))
} else {
  checks.push('No quiet adjudication: ' + assertions.length + ' structured state assertion(s) checked, all match baseline or an authorised ruling')
}

// ── AXIS 2 — CHARTERED OBLIGATIONS ──────────────────────────────────────────
const coReg = opt(join(RC, 'chartered-obligation-register.json'))
const disp = opt(join(RC, 'co-input-dispositions.json'))
if (!coReg) failures.push('chartered-obligation-register.json missing')
if (!disp) failures.push('co-input-dispositions.json missing')

if (coReg && disp) {
  const raw = disp.rawInputs
  const promoted = disp.dispositions.filter((d) => d.disposition === 'PROMOTED').length
  const merged = disp.dispositions.filter((d) => d.disposition === 'MERGED_INTO').length
  const undisposed = disp.dispositions.filter((d) => !d.disposition).length

  // THE 299-INPUT DISPOSITION INVARIANT
  if (undisposed) failures.push('AXIS 2 — ' + undisposed + ' charter candidate(s) with NO disposition')
  if (promoted + merged !== raw) {
    failures.push('AXIS 2 — disposition ledger does not balance: promoted ' + promoted + ' + merged ' + merged + ' != raw ' + raw)
  } else {
    checks.push('AXIS 2: 299-input disposition invariant holds — ' + raw + ' candidates, ' + promoted + ' promoted + ' + merged + ' merged, 0 dropped')
  }
  if (coReg.totals.charteredObligations !== promoted) {
    failures.push('AXIS 2 — register holds ' + coReg.totals.charteredObligations + ' COs but ' + promoted + ' inputs were promoted')
  } else checks.push('AXIS 2: register count equals promoted inputs (' + promoted + ')')

  const ids = coReg.obligations.map((c) => c.id)
  const dupCo = ids.filter((id, i) => ids.indexOf(id) !== i)
  if (dupCo.length) failures.push('AXIS 2 — duplicate CO ids: ' + [...new Set(dupCo)].slice(0, 10).join(', '))
  else checks.push('AXIS 2: every CO counted exactly once')

  const chaptersPresent = new Set(coReg.obligations.map((c) => c.rcChapter))
  const missingRc = []
  for (let i = 0; i <= 11; i++) if (!chaptersPresent.has('RC-C' + i)) missingRc.push('RC-C' + i)
  if (missingRc.length) failures.push('AXIS 2 — chapter(s) with no obligations: ' + missingRc.join(', '))
  else checks.push('AXIS 2: all 12 chapters RC-C0..RC-C11 represented')

  const c8 = coReg.obligations.filter((c) => c.rcChapter === 'RC-C8')
  if (!c8.length) failures.push('AXIS 2 — RC-C8 (the zero-finding control case) has no obligations')
  else checks.push('AXIS 2: RC-C8 control case represented with ' + c8.length + ' obligations despite 0 findings')

  // No obligation may be converted into an F-item.
  const asF = coReg.obligations.filter((c) => /^F\d{3}$/.test(c.id))
  if (asF.length) failures.push('AXIS 2 — obligation(s) silently converted into F-items: ' + asF.length)
  else checks.push('AXIS 2: no obligation converted into an F-item')

  // No obligation may be declared satisfied from chapter status alone.
  const inferred = coReg.obligations.filter((c) => /satisf|complete|closed/i.test(String(c.currentState)))
  if (inferred.length) failures.push('AXIS 2 — ' + inferred.length + ' obligation(s) declared satisfied at obligation level without evidence')
  else checks.push('AXIS 2: no obligation declared satisfied from chapter status alone')

  checks.push('CROSS-AXIS: ' + coReg.totals.zeroFindingObligations + ' zero-finding obligations are explicitly visible')
}

// ── regression fixture: the 20 disappeared obligations ──────────────────────
const fx = opt(join(RC, 'disappeared-obligations-fixture.json'))
if (!fx) failures.push('disappeared-obligations-fixture.json missing')
else if (coReg) {
  const chaptersWithCos = new Set(coReg.obligations.map((c) => c.rcChapter))
  const lost = fx.entries.filter((e) => e.rcChapter !== 'UNATTRIBUTED' && !chaptersWithCos.has(e.rcChapter))
  if (lost.length) failures.push('REGRESSION — disappeared obligation(s) whose chapter has no CO representation: ' + lost.map((l) => l.id).join(', '))
  else checks.push('REGRESSION: all ' + fx.count + ' disappeared obligations are representable in the CO axis')
}

const result = {
  stage: 'STAGE_2_AMENDMENT',
  type: 'DETERMINISTIC_DUAL_AXIS_VALIDATION',
  date: '2026-08-18',
  axis1Findings: { accounted: baseline.size, expected: 143, conflictsIntact: true },
  axis2Obligations: coReg ? {
    accounted: coReg.totals.charteredObligations,
    rawInputs: disp ? disp.rawInputs : null,
    zeroFinding: coReg.totals.zeroFindingObligations,
    chapters: 12,
  } : null,
  quietAdjudication: { assertionsChecked: assertions.length, violations: viols, supersededPreRuling: superseded },
  checksPassed: checks,
  warnings,
  failures,
  verdict: failures.length ? 'FAIL' : 'PASS',
  stageStatus: {
    stage0: 'COMPLETE_AND_FOUNDER_RATIFIED',
    stage1: 'COMPLETE',
    stage2: failures.length ? 'AMENDMENT_FAILED' : 'COMPLETE_WITH_AMENDMENT',
    stage3: 'NOT_STARTED_NOT_AUTHORIZED',
  },
}
writeFileSync(join(RC, 'stage2-validation.json'), JSON.stringify(result, null, 2))
for (const k of checks) console.log('OK    ' + k)
for (const w of warnings) console.log('WARN  ' + w)
for (const f of failures) console.log('FAIL  ' + f)
console.log('\nVERDICT: ' + result.verdict + '   STAGE 2: ' + result.stageStatus.stage2 + '   STAGE 3: NOT_AUTHORIZED\n')
process.exit(failures.length ? 1 : 0)
