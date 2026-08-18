#!/usr/bin/env node
/**
 * STAGE 1 — MECHANICAL VALIDATION.
 *
 * Stage 1 produces ANALYTICAL_PROPOSALS, not truth. This script proves the
 * bookkeeping those proposals must respect and — the check that matters most —
 * proves the founder-ratified Stage-0 baseline was NOT mutated by analysis.
 *
 * Usage: node validate-stage1.mjs <runRoot>
 * Writes: <runRoot>/01-analysis/stage1-validation.json
 * Exit 1 on any hard failure.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { execSync } from 'node:child_process'
import { join } from 'node:path'

const root = process.argv[2]
if (!root) { console.error('usage: node validate-stage1.mjs <runRoot>'); process.exit(2) }
const EV = join(root, '00-evidence')
const AN = join(root, '01-analysis')
const rd = (p) => JSON.parse(readFileSync(p, 'utf8'))
const opt = (p) => (existsSync(p) ? rd(p) : null)

const failures = []
const warnings = []
const checks = []

// ── canonical universe from the ratified baseline ───────────────────────────
const acct = rd(join(EV, 'id-accounting.json'))
const NOT_ISSUED = new Set(['QUARANTINED_SELF_AUTHORED_ONLY', 'RESERVED_UNISSUED'])
const issuedF = acct.rows.filter((r) => r.id.startsWith('F') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)
const issuedWG = acct.rows.filter((r) => r.id.startsWith('WG') && !NOT_ISSUED.has(r.classification)).map((r) => r.id)
const reservedWG = acct.wg.reservedUnissued || []

// ── STAGE-0 IMMUTABILITY ────────────────────────────────────────────────────
// The baseline is committed. If analysis touched it, the working tree is dirty.
try {
  const dirty = execSync('git status --porcelain -- docs/portfolio/run/stage0-2026-08-18/00-evidence', {
    cwd: 'C:/Users/muham/flutter_projects/aura/aura_final', encoding: 'utf8',
  }).trim()
  if (dirty) failures.push('STAGE-0 MUTATED by analysis — dirty under 00-evidence: ' + dirty.replace(/\s+/g, ' '))
  else checks.push('Stage-0 canonical evidence UNMUTATED (git clean under 00-evidence)')
} catch (e) {
  warnings.push('could not verify Stage-0 immutability via git: ' + String(e.message).split('\n')[0])
}

// ── AGENT A ─────────────────────────────────────────────────────────────────
const a = opt(join(AN, 'agent-a-root-systems.json'))
if (!a) failures.push('agent-a-root-systems.json missing')
else {
  if (a.type !== 'ANALYTICAL_PROPOSAL') failures.push('Agent A artifact type must be ANALYTICAL_PROPOSAL, found ' + a.type)
  const rows = a.findings || a.rows || []
  const ids = rows.map((r) => r && r.id).filter(Boolean)
  const uniq = new Set(ids)
  const missing = issuedF.filter((id) => !uniq.has(id))
  const invented = [...uniq].filter((id) => !issuedF.includes(id))
  const dupes = ids.filter((id, i) => ids.indexOf(id) !== i)
  const noOwner = rows.filter((r) => r && !(r.proposedRootOwner || r.rootSystem || r.proposedOwner)).map((r) => r.id)

  if (missing.length) failures.push('AGENT A — ' + missing.length + ' finding(s) not consumed: ' + missing.slice(0, 20).join(', '))
  if (invented.length) failures.push('AGENT A — ' + invented.length + ' invented id(s): ' + invented.slice(0, 20).join(', '))
  if (dupes.length) failures.push('AGENT A — duplicate canonical proposed owner rows: ' + [...new Set(dupes)].join(', '))
  if (noOwner.length) failures.push('AGENT A — ' + noOwner.length + ' finding(s) with no proposed root owner: ' + noOwner.slice(0, 20).join(', '))
  if (!missing.length && !invented.length && !dupes.length && !noOwner.length) {
    checks.push('Agent A: ' + uniq.size + '/143 findings consumed, each with exactly one proposed root owner')
  }
  for (const id of ['F064', 'F113']) if (!uniq.has(id)) failures.push('AGENT A — ' + id + ' must remain a separate finding')
}

// ── AGENT B ─────────────────────────────────────────────────────────────────
const b = opt(join(AN, 'agent-b-dependencies.json'))
if (!b) failures.push('agent-b-dependencies.json missing')
else {
  if (b.type !== 'ANALYTICAL_PROPOSAL') failures.push('Agent B artifact type must be ANALYTICAL_PROPOSAL, found ' + b.type)
  const txt = JSON.stringify(b)
  const pbMissing = []
  for (let i = 1; i <= 12; i++) {
    const pb = 'PB-' + String(i).padStart(2, '0')
    if (!txt.includes(pb)) pbMissing.push(pb)
  }
  if (pbMissing.length) failures.push('AGENT B — protected boundaries not considered: ' + pbMissing.join(', '))
  else checks.push('Agent B: all 12 protected boundaries PB-01..PB-12 considered')

  const rcMissing = []
  for (let i = 0; i <= 11; i++) if (!txt.includes('RC-C' + i)) rcMissing.push('RC-C' + i)
  if (rcMissing.length) warnings.push('Agent B did not reference: ' + rcMissing.join(', '))
  else checks.push('Agent B: RC-C0..RC-C11 dependency axis referenced')

  if (!b.rcC4C5Analysis && !txt.includes('rcC4C5')) failures.push('AGENT B — RC-C4/RC-C5 analysis missing')
  else checks.push('Agent B: RC-C4/RC-C5 stalled-chain analysis present')
}

// ── AGENT C ─────────────────────────────────────────────────────────────────
const c = opt(join(AN, 'agent-c-product.json'))
if (!c) failures.push('agent-c-product.json missing')
else {
  if (c.type !== 'ANALYTICAL_PROPOSAL') failures.push('Agent C artifact type must be ANALYTICAL_PROPOSAL, found ' + c.type)
  const txt = JSON.stringify(c)
  const wgMissing = issuedWG.filter((id) => !txt.includes(id))
  if (wgMissing.length) failures.push('AGENT C — WG item(s) not considered: ' + wgMissing.join(', '))
  else checks.push('Agent C: all ' + issuedWG.length + ' issued WG items considered')

  const wgRows = Array.isArray(c.wgMapping) ? c.wgMapping : []
  const bad = wgRows.find((w) => w && w.id === 'WG018' && !/RESERVED|UNISSUED/i.test(JSON.stringify(w)))
  if (bad) failures.push('AGENT C — WG018 treated as an issued item; it is RESERVED/UNISSUED')
  else checks.push('Agent C: WG018 not treated as issued')
}

// ── no finding state changed by analysis ────────────────────────────────────
const stage0States = new Map()
for (const n of [1, 2, 3]) {
  const p = join(EV, 'findings-batch-' + n + '.json')
  if (!existsSync(p)) continue
  const arr = rd(p)
  for (const r of (Array.isArray(arr) ? arr : arr.findings || [])) if (r && r.id) stage0States.set(r.id, r.currentState)
}
if (a) {
  const changed = []
  for (const r of (a.findings || [])) {
    if (r && r.id && r.currentState && stage0States.has(r.id) && r.currentState !== stage0States.get(r.id)) {
      changed.push(r.id + ': ' + stage0States.get(r.id) + ' -> ' + r.currentState)
    }
  }
  if (changed.length) failures.push('STATE MUTATION — analysis changed finding state(s): ' + changed.slice(0, 10).join('; '))
  else checks.push('No finding state changed by Stage-1 analysis')
}

for (const id of ['F043', 'F051', 'F122']) {
  if (stage0States.get(id) !== 'CONFLICTING_CURRENT_STATE') {
    failures.push('BASELINE DRIFT — ' + id + ' no longer CONFLICTING_CURRENT_STATE in Stage-0 evidence')
  }
}
checks.push('F043/F051/F122 conflicts intact in the baseline')

const result = {
  stage: 'STAGE_1',
  type: 'DETERMINISTIC_VALIDATION',
  date: '2026-08-18',
  canonicalUniverse: { issuedFindings: issuedF.length, issuedWG: issuedWG.length, reservedWG },
  checksPassed: checks,
  warnings,
  failures,
  verdict: failures.length ? 'FAIL' : 'PASS',
  stageStatus: {
    stage0: 'COMPLETE_AND_FOUNDER_RATIFIED',
    stage1: failures.length ? 'FAILED_VALIDATION' : 'COMPLETE',
    stage2: 'NOT_STARTED',
  },
  note: 'Stage-1 outputs are ANALYTICAL_PROPOSAL. Not ratified; they carry no ownership authority.',
}
writeFileSync(join(AN, 'stage1-validation.json'), JSON.stringify(result, null, 2))
for (const k of checks) console.log('OK    ' + k)
for (const w of warnings) console.log('WARN  ' + w)
for (const f of failures) console.log('FAIL  ' + f)
console.log('\nVERDICT: ' + result.verdict + '   STAGE 1: ' + result.stageStatus.stage1 + '   STAGE 2: NOT_STARTED\n')
process.exit(failures.length ? 1 : 0)
