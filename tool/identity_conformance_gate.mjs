#!/usr/bin/env node
// CH-03 — THE IDENTITY CONFORMANCE GATE.
//
// F053 as issued: "THE CANONICAL IDENTITY SYSTEM IS NOT BEING CONSUMED
// CONSISTENTLY ACROSS THE PRODUCT." PB-05 states the exit condition: F116 may
// NOT be closed by fixing one consumer — a systematic consumer audit with an
// ENUMERATED consumer list is required.
//
// W1-F produced that list. This is the other half: the gate that keeps it
// true. An audit is a photograph; a gate is a contract.
//
// WHAT IT ENFORCES — a ratchet, in both directions:
//   * no NEW file may introduce a non-conformant identity consumer;
//   * no existing file's non-conformant count may RISE;
//   * if a count FALLS the gate fails until the baseline is updated, so the
//     register can never overstate remaining identity debt.
//
// WHAT IT DELIBERATELY DOES NOT DO. It does not require the existing debt to
// be zero, and it does not fail on the current population. Demanding zero
// today would either block every unrelated change or invite the baseline to be
// quietly regenerated — which is how a gate becomes decoration.
//
// Usage:
//   node tool/identity_conformance_gate.mjs            check against baseline
//   node tool/identity_conformance_gate.mjs --freeze   rewrite the baseline
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(HERE, '..')
const AUDIT = resolve(HERE, 'identity_consumer_audit.mjs')
const AUDIT_OUT = resolve(ROOT, 'docs/portfolio/run/stage0-2026-08-18/05-execution/w1f-identity-consumer-audit.json')
const BASELINE = resolve(HERE, 'identity-conformance-baseline.json')

/// The verdicts that represent identity debt. Both are non-conformance; they
/// are counted separately because they are different defects — one is a
/// surface resolving identity for itself, the other is a projection that
/// hand-picks person fields instead of composing the canonical shape.
const DEBT_VERDICTS = ['NON_CONFORMANT', 'ADHOC_MAP_EXTRACTION_IN_SURFACE']

function runAudit() {
  execFileSync(process.execPath, [AUDIT], { cwd: ROOT, stdio: 'pipe' })
  return JSON.parse(readFileSync(AUDIT_OUT, 'utf8'))
}

function measure(audit) {
  const perFile = {}
  for (const row of audit.consumers) {
    if (!DEBT_VERDICTS.includes(row.verdict)) continue
    const key = `${row.repo}:${row.path}`
    perFile[key] = (perFile[key] || 0) + 1
  }
  return perFile
}

const audit = runAudit()
const actual = measure(audit)

if (process.argv.includes('--freeze')) {
  writeFileSync(
    BASELINE,
    JSON.stringify(
      {
        artifact: 'IDENTITY_CONFORMANCE_BASELINE',
        frozen: '2026-08-18',
        rule: 'Counts may FALL (update this file when they do) but may never RISE, and no new file may appear.',
        authority: { frontend: ['AuraAvatar', 'AuraIdentitySurface'], backend: ['PERSON_IDENTITY_SELECT', 'PERSON_REFERENCE_SELECT'] },
        debtVerdicts: DEBT_VERDICTS,
        totals: { files: Object.keys(actual).length, sites: Object.values(actual).reduce((a, b) => a + b, 0) },
        perFile: actual,
      },
      null,
      1,
    ),
  )
  console.log('FROZEN:', Object.keys(actual).length, 'files /', Object.values(actual).reduce((a, b) => a + b, 0), 'sites')
  process.exit(0)
}

if (!existsSync(BASELINE)) {
  console.error('FAIL-CLOSED: no identity conformance baseline. Run with --freeze to create it.')
  process.exit(1)
}
const baseline = JSON.parse(readFileSync(BASELINE, 'utf8')).perFile

const appeared = Object.keys(actual).filter((k) => !(k in baseline)).sort()
const rose = Object.entries(actual)
  .filter(([k, v]) => k in baseline && v > baseline[k])
  .map(([k, v]) => `${k}: ${baseline[k]} -> ${v}`)
  .sort()
const fell = Object.entries(baseline)
  .filter(([k, v]) => (actual[k] ?? 0) < v)
  .map(([k, v]) => `${k}: ${v} -> ${actual[k] ?? 0}`)
  .sort()

let failed = false
if (appeared.length) {
  failed = true
  console.error('\n[IDENTITY CONFORMANCE] NEW non-conformant identity consumer introduced in:')
  for (const a of appeared) console.error('  ' + a)
  console.error(
    '\nConsume the canonical identity system: AuraAvatar / AuraIdentitySurface on the client,\n' +
      'PERSON_IDENTITY_SELECT / PERSON_REFERENCE_SELECT on the server. A context-specific\n' +
      'projection is legitimate; independently reinventing one is not.\n',
  )
}
if (rose.length) {
  failed = true
  console.error('\n[IDENTITY CONFORMANCE] identity debt ROSE in:')
  for (const r of rose) console.error('  ' + r)
}
if (fell.length) {
  failed = true
  console.error('\n[IDENTITY CONFORMANCE] debt was REDUCED (good) but the baseline now overstates it:')
  for (const f of fell) console.error('  ' + f)
  console.error('\nRe-freeze so the register stays truthful: node tool/identity_conformance_gate.mjs --freeze\n')
}

const files = Object.keys(actual).length
const sites = Object.values(actual).reduce((a, b) => a + b, 0)
console.log(`identity debt: ${files} files / ${sites} sites   (baseline ${Object.keys(baseline).length} / ${Object.values(baseline).reduce((a, b) => a + b, 0)})`)
console.log(failed ? 'IDENTITY CONFORMANCE GATE: FAIL' : 'IDENTITY CONFORMANCE GATE: PASS')
process.exit(failed ? 1 : 0)
