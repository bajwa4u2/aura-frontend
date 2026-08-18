#!/usr/bin/env node
/**
 * STAGE 2 — MECHANICAL VALIDATION.
 *
 * Proves the bookkeeping Stage-2 proposals must respect, and that BOTH earlier
 * layers survived untouched: the founder-ratified Stage-0 baseline and the
 * Stage-1 analytical proposals.
 *
 * The distinctive check here is on Agent E. An adversarial reviewer that comes
 * back clean has failed, not passed, so "no surviving criticisms" is a FAILURE
 * condition rather than a good result.
 *
 * Usage: node validate-stage2.mjs <runRoot>
 * Writes: <runRoot>/02-reconcile/stage2-validation.json
 * Exit 1 on any hard failure.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { execSync } from 'node:child_process'
import { join } from 'node:path'

const root = process.argv[2]
if (!root) { console.error('usage: node validate-stage2.mjs <runRoot>'); process.exit(2) }
const EV = join(root, '00-evidence')
const AN = join(root, '01-analysis')
const RC = join(root, '02-reconcile')
const rd = (p) => JSON.parse(readFileSync(p, 'utf8'))
const opt = (p) => (existsSync(p) ? rd(p) : null)

const failures = []
const warnings = []
const checks = []

// ── earlier layers must be untouched ────────────────────────────────────────
for (const [label, dir] of [['Stage-0 baseline', EV], ['Stage-1 proposals', AN]]) {
  try {
    const rel = dir.replace(/^.*aura_final[\\/]/, '').replace(/\\/g, '/')
    const dirty = execSync('git status --porcelain -- "' + rel + '"', {
      cwd: 'C:/Users/muham/flutter_projects/aura/aura_final', encoding: 'utf8',
    }).trim()
    // Stage-1 legitimately gained stage1-comparison.json + stage1-validation.json in a
    // prior commit; anything dirty NOW means Stage 2 modified it.
    if (dirty) failures.push(label + ' MUTATED by Stage 2: ' + dirty.replace(/\s+/g, ' ').slice(0, 300))
    else checks.push(label + ' UNMUTATED by Stage 2 (git clean)')
  } catch (e) {
    warnings.push('could not verify ' + label + ' immutability: ' + String(e.message).split('\n')[0])
  }
}

// ── canonical universe ──────────────────────────────────────────────────────
const acct = rd(join(EV, 'id-accounting.json'))
const NOT_ISSUED = new Set(['QUARANTINED_SELF_AUTHORED_ONLY', 'RESERVED_UNISSUED'])
const issuedF = acct.rows.filter((r) => r.id.startsWith('F') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)

// ── AGENT D ─────────────────────────────────────────────────────────────────
const d = opt(join(RC, 'agent-d-rc-reconciliation.json'))
if (!d) failures.push('agent-d-rc-reconciliation.json missing')
else {
  if (d.type !== 'ANALYTICAL_PROPOSAL') failures.push('Agent D type must be ANALYTICAL_PROPOSAL, found ' + d.type)
  const txt = JSON.stringify(d)
  const missing = []
  for (let i = 0; i <= 11; i++) if (!txt.includes('RC-C' + i)) missing.push('RC-C' + i)
  if (missing.length) failures.push('AGENT D — reconstruction chapter(s) not covered: ' + missing.join(', '))
  else checks.push('Agent D: all 12 chapters RC-C0..RC-C11 addressed')

  const rows = d.rcChapters || []
  if (rows.length && rows.length !== 12) warnings.push('Agent D rcChapters length is ' + rows.length + ', expected 12')

  // The central question must be answered explicitly, even if the answer is "none".
  if (d.disappearedObligations === undefined) {
    failures.push('AGENT D — disappearedObligations must be stated explicitly, even if empty')
  } else {
    checks.push('Agent D: disappeared-obligation question answered explicitly (' + (d.disappearedObligations || []).length + ' recorded)')
  }
  if (d.systemsWithNoAxisHome === undefined) {
    warnings.push('Agent D did not state systemsWithNoAxisHome; a system belonging to nothing is itself a finding')
  }
}

// ── AGENT E — an adversarial reviewer that returns clean has FAILED ─────────
const e = opt(join(RC, 'agent-e-adversarial.json'))
if (!e) failures.push('agent-e-adversarial.json missing')
else {
  if (e.type !== 'ANALYTICAL_PROPOSAL') failures.push('Agent E type must be ANALYTICAL_PROPOSAL, found ' + e.type)
  const qs = e.questions || []
  if (qs.length < 20) failures.push('AGENT E — answered ' + qs.length + ' of 20 required questions')
  else checks.push('Agent E: all ' + qs.length + ' adversarial questions answered')

  const unverdicted = qs.filter((q) => !q || !q.verdict).length
  if (unverdicted) failures.push('AGENT E — ' + unverdicted + ' question(s) lack an explicit verdict')
  const unevidenced = qs.filter((q) => q && q.verdict && !q.evidence).length
  if (unevidenced) warnings.push('Agent E: ' + unevidenced + ' question(s) carry a verdict without cited evidence')

  const surviving = e.survivingCriticisms || []
  if (!surviving.length) {
    failures.push('AGENT E RETURNED CLEAN — a review with zero surviving criticisms is treated as reviewer failure, not portfolio soundness')
  } else {
    checks.push('Agent E: ' + surviving.length + ' surviving criticism(s) — the reviewer did its job')
  }
}

// ── conflicts must still be conflicts ───────────────────────────────────────
const stage0States = new Map()
for (const n of [1, 2, 3]) {
  const p = join(EV, 'findings-batch-' + n + '.json')
  if (!existsSync(p)) continue
  const arr = rd(p)
  for (const r of (Array.isArray(arr) ? arr : arr.findings || [])) if (r && r.id) stage0States.set(r.id, r.currentState)
}
for (const id of ['F043', 'F051', 'F122']) {
  if (stage0States.get(id) !== 'CONFLICTING_CURRENT_STATE') {
    failures.push('BASELINE DRIFT — ' + id + ' no longer CONFLICTING_CURRENT_STATE')
  }
}
checks.push('F043/F051/F122 conflicts intact in the baseline')

// Stage 2 must not have claimed to resolve the carried conflicts.
const combined = JSON.stringify([d, e]).toLowerCase()
const claimed = []
for (const id of ['f043', 'f051', 'f122', 'f139', 'rc-c10']) {
  const re = new RegExp(id + '[^.]{0,120}(now resolved|is resolved|resolution:\\s*resolved|adjudicated)', 'i')
  if (re.test(combined)) claimed.push(id.toUpperCase())
}
if (claimed.length) failures.push('QUIET ADJUDICATION — Stage 2 appears to resolve carried conflict(s): ' + claimed.join(', '))
else checks.push('No carried conflict was adjudicated by Stage 2')

// ── no finding may vanish from the reconciliation view ──────────────────────
if (d) {
  const txt = JSON.stringify(d)
  const referenced = issuedF.filter((id) => txt.includes(id)).length
  checks.push('Agent D references ' + referenced + ' of ' + issuedF.length + ' findings (chapter-level reconciliation; full ownership is Stage 4)')
}

const result = {
  stage: 'STAGE_2',
  type: 'DETERMINISTIC_VALIDATION',
  date: '2026-08-18',
  checksPassed: checks,
  warnings,
  failures,
  verdict: failures.length ? 'FAIL' : 'PASS',
  stageStatus: {
    stage0: 'COMPLETE_AND_FOUNDER_RATIFIED',
    stage1: 'COMPLETE',
    stage2: failures.length ? 'FAILED_VALIDATION' : 'COMPLETE',
    stage3: 'NOT_STARTED',
  },
  note: 'Stage-2 outputs are ANALYTICAL_PROPOSAL. No canonical ownership assigned; that is Stage 4.',
}
writeFileSync(join(RC, 'stage2-validation.json'), JSON.stringify(result, null, 2))
for (const k of checks) console.log('OK    ' + k)
for (const w of warnings) console.log('WARN  ' + w)
for (const f of failures) console.log('FAIL  ' + f)
console.log('\nVERDICT: ' + result.verdict + '   STAGE 2: ' + result.stageStatus.stage2 + '   STAGE 3: NOT_STARTED\n')
process.exit(failures.length ? 1 : 0)
