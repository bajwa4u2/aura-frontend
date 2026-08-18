#!/usr/bin/env node
// FOUNDER RULING 3 — mechanical reconciliation of the PD-1 G5 count (34 vs 35).
//
// The instruction is explicit: compare the underlying canonical SITE SETS, not
// the totals, and escalate only if the sets encode conflicting product scope or
// governance intent. This compares the two populations file by file.
//
// SOURCE A — C1_G5_DISPOSITION_MATRIX.md, the originating PD-1 enumeration.
//            Its header states "11 files · 34 sites"; its per-file table rows
//            are the actual enumeration.
// SOURCE B — test/product/c0_drift_baseline.txt, the frozen, machine-measured,
//            ratchet-enforced baseline (2026-08-15).
import { readFileSync, writeFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(HERE, '../../..')
const MATRIX = resolve(ROOT, 'docs/frontend-discovery/C1_G5_DISPOSITION_MATRIX.md')
const BASELINE = resolve(ROOT, 'test/product/c0_drift_baseline.txt')
const OUT = resolve(HERE, '../run/stage0-2026-08-18/05-execution/pd1-g5-count-reconciliation.json')

// ── SOURCE A: parse the PD-1 section's per-file rows ────────────────────────
const matrixText = readFileSync(MATRIX, 'utf8')
const start = matrixText.indexOf('PD-1 — PLATFORM ADMINISTRATION')
if (start === -1) throw new Error('FAIL-CLOSED: PD-1 section not found in the matrix')
const section = matrixText.slice(start, matrixText.indexOf('\n### ', start + 10) === -1
  ? start + 4000
  : matrixText.indexOf('\n### ', start + 10))

const declaredHeader = section.match(/\*\*(\d+)\s+files\s*·\s*(\d+)\s+sites\*\*/)
if (!declaredHeader) throw new Error('FAIL-CLOSED: PD-1 header figure not parsable')

const rowRe = /\|\s*`(admin_[a-z_]+\.dart)`\s*\((\d+)\)\s*\|/g
const sourceA = {}
let m
while ((m = rowRe.exec(section)) !== null) sourceA[m[1]] = Number(m[2])
if (Object.keys(sourceA).length === 0) throw new Error('FAIL-CLOSED: no PD-1 per-file rows parsed')

// ── SOURCE B: parse G5 rows for admin/presentation from the frozen baseline ──
const sourceB = {}
for (const raw of readFileSync(BASELINE, 'utf8').split(/\r?\n/)) {
  const line = raw.trim()
  if (!line || line.startsWith('#')) continue
  const [rule, count, path] = line.split(/\s+/)
  if (rule !== 'G5') continue
  if (!path.startsWith('lib/features/admin/presentation/')) continue
  sourceB[path.split('/').pop()] = Number(count)
}

// ── Compare the SETS, file by file ──────────────────────────────────────────
const files = [...new Set([...Object.keys(sourceA), ...Object.keys(sourceB)])].sort()
const perFile = files.map((f) => ({
  file: f,
  matrix: sourceA[f] ?? null,
  baseline: sourceB[f] ?? null,
  agrees: (sourceA[f] ?? null) === (sourceB[f] ?? null),
}))
const disagreements = perFile.filter((r) => !r.agrees)
const onlyInA = files.filter((f) => !(f in sourceB))
const onlyInB = files.filter((f) => !(f in sourceA))

const sumA = Object.values(sourceA).reduce((a, b) => a + b, 0)
const sumB = Object.values(sourceB).reduce((a, b) => a + b, 0)
const headerFiles = Number(declaredHeader[1])
const headerSites = Number(declaredHeader[2])

// ── Verdict ─────────────────────────────────────────────────────────────────
const setsIdentical = disagreements.length === 0 && onlyInA.length === 0 && onlyInB.length === 0
let cause, escalate, operative
if (setsIdentical && sumA === sumB && sumA !== headerSites) {
  cause = 'SUMMATION_ERROR_IN_THE_SUMMARY_LINE'
  escalate = false
  operative = sumA
} else if (!setsIdentical) {
  cause = 'ACTUALLY_DIFFERENT_SITE_POPULATIONS'
  escalate = true
  operative = null
} else {
  cause = 'NO_DISCREPANCY'
  escalate = false
  operative = sumA
}

const out = {
  type: 'PD1_G5_COUNT_RECONCILIATION',
  ruling: 'FOUNDER RULING 3 (2026-08-18) — reconcile mechanically; escalate only if the underlying sets encode conflicting product scope or governance intent.',
  date: '2026-08-18',
  method: 'Per-file comparison of the two canonical site populations. Totals were not compared until the sets were shown to match.',
  sources: {
    A: { artifact: 'docs/frontend-discovery/C1_G5_DISPOSITION_MATRIX.md', section: 'PD-1 — PLATFORM ADMINISTRATION',
         headerClaim: { files: headerFiles, sites: headerSites },
         enumeratedRows: Object.keys(sourceA).length, enumeratedSum: sumA },
    B: { artifact: 'test/product/c0_drift_baseline.txt', measured: '2026-08-15, machine-measured, ratchet-enforced',
         rows: Object.keys(sourceB).length, sum: sumB },
  },
  setComparison: {
    filesInBoth: files.length - onlyInA.length - onlyInB.length,
    onlyInMatrix: onlyInA,
    onlyInBaseline: onlyInB,
    perFileDisagreements: disagreements,
    setsIdentical,
  },
  perFile,
  finding: setsIdentical
    ? `The two site populations are IDENTICAL: the same ${files.length} files, and every per-file count agrees. Source A's own enumerated rows sum to ${sumA}, but Source A's summary line states ${headerSites}. The 34 is an arithmetic error in a summary line, not a different set of sites.`
    : 'The site populations DIFFER. This requires founder attention.',
  cause,
  escalateToFounder: escalate,
  operativeCount: operative,
  disposition: setsIdentical ? {
    historicalFiguresPreserved: [
      { value: 34, source: 'C1_G5_DISPOSITION_MATRIX.md PD-1 summary line, propagated to docs/NEXT_WORK.md:62-65, thence to 00-evidence/rc-map.json RC-C11.explicitlyRemainingObligations[1] and CO-RC-C11-005', status: 'RETAINED_AS_HISTORICAL_EVIDENCE_WITH_PROVENANCE — not rewritten' },
      { value: 35, source: 'test/product/c0_drift_baseline.txt (frozen 2026-08-15)', status: 'CURRENT_OPERATIVE_COUNT' },
    ],
    correction: 'SUMMATION_CORRECTION — 34 is SUPERSEDED_BY_CURRENT_VERIFICATION at 35. The underlying obligation, the 11-file set and every per-file count are unchanged.',
    productScopeChanged: false,
    governanceIntentChanged: false,
    canonicalUnitsAffected: 0,
    closedWithoutFounderEscalation: true,
    note: 'No product or governance judgement was required, so per ruling 3 this is closed here rather than returned to founder attention.',
  } : null,
}
writeFileSync(OUT, JSON.stringify(out, null, 1))

console.log('files compared      :', files.length)
console.log('sets identical      :', setsIdentical)
console.log('matrix header claim :', headerFiles, 'files /', headerSites, 'sites')
console.log('matrix rows sum     :', sumA)
console.log('baseline sum        :', sumB)
console.log('cause               :', cause)
console.log('escalate to founder :', escalate)
console.log('operative count     :', operative)
if (!setsIdentical) process.exit(1)
