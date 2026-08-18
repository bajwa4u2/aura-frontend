#!/usr/bin/env node
/**
 * STAGE 4 — DETERMINISTIC PORTFOLIO RECONCILIATION.
 *
 * Part VII demands an accounting PROOF. A language model emitting "142 == 142" is
 * an assertion; this script computing it is a proof. Reconciliation is pure set
 * arithmetic and must never be delegated to a model, which can hallucinate a
 * balanced ledger.
 *
 * Usage:  node verify-portfolio.mjs <runRoot> [--compare <previousRunRoot>]
 *
 * Reads:  <runRoot>/00-evidence/findings.jsonl
 *         <runRoot>/00-evidence/wg.jsonl
 *         <runRoot>/00-evidence/register-anomalies.json
 *         <runRoot>/03-synthesis/portfolio.json
 * Writes: <runRoot>/04-proof/reconciliation.json
 *
 * Exit 0 = all invariants hold. Exit 1 = the run FAILS and the portfolio must not
 * be published. Read-only with respect to every canonical register.
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const [runRoot, ...rest] = process.argv.slice(2)
if (!runRoot) {
  console.error('usage: node verify-portfolio.mjs <runRoot> [--compare <previousRunRoot>]')
  process.exit(2)
}
const compareIdx = rest.indexOf('--compare')
const compareRoot = compareIdx >= 0 ? rest[compareIdx + 1] : null

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'))
const readJsonl = (p) =>
  readFileSync(p, 'utf8')
    .split(/\r?\n/)
    .filter((l) => l.trim())
    .map((l, i) => {
      try {
        return JSON.parse(l)
      } catch (e) {
        return { __malformed: true, line: i + 1, raw: l.slice(0, 200) }
      }
    })

const findingsPath = join(runRoot, '00-evidence', 'findings.jsonl')
const wgPath = join(runRoot, '00-evidence', 'wg.jsonl')
const portfolioPath = join(runRoot, '03-synthesis', 'portfolio.json')

for (const p of [findingsPath, portfolioPath]) {
  if (!existsSync(p)) {
    console.error(`FAIL — required artifact missing: ${p}`)
    process.exit(1)
  }
}

const findings = readJsonl(findingsPath)
const wg = existsSync(wgPath) ? readJsonl(wgPath) : []
const portfolio = readJson(portfolioPath)
const anomaliesPath = join(runRoot, '00-evidence', 'register-anomalies.json')
const anomalies = existsSync(anomaliesPath) ? readJson(anomaliesPath) : {}

const failures = []
const warnings = []

// ── Source register ─────────────────────────────────────────────────────────
const malformed = findings.filter((f) => f.__malformed)
const clean = findings.filter((f) => !f.__malformed && f.id)
const sourceIds = clean.map((f) => f.id)
const sourceSet = new Set(sourceIds)

const dupeCounts = {}
for (const id of sourceIds) dupeCounts[id] = (dupeCounts[id] || 0) + 1
const duplicatesInSource = Object.keys(dupeCounts).filter((k) => dupeCounts[k] > 1)

if (malformed.length) {
  failures.push(`${malformed.length} malformed record(s) in findings.jsonl`)
}

// ── Portfolio ownership ─────────────────────────────────────────────────────
const chapters = Array.isArray(portfolio.chapters) ? portfolio.chapters : []
if (!chapters.length) failures.push('portfolio.json contains no chapters')

const ownerOf = new Map()
const ownedTwice = []
for (const ch of chapters) {
  for (const id of ch.canonicalFindings || []) {
    if (ownerOf.has(id)) ownedTwice.push({ id, chapters: [ownerOf.get(id), ch.id] })
    else ownerOf.set(id, ch.id)
  }
}

// R1 — exactly one canonical owner, and the totals must balance.
const ownedIds = new Set(ownerOf.keys())
const unowned = [...sourceSet].filter((id) => !ownedIds.has(id))
const ownedNotInSource = [...ownedIds].filter((id) => !sourceSet.has(id))

if (ownedTwice.length) {
  failures.push(
    `R1 VIOLATED — ${ownedTwice.length} finding(s) claimed by more than one chapter: ` +
      ownedTwice.slice(0, 10).map((d) => `${d.id}[${d.chapters.join(',')}]`).join(', '),
  )
}
if (unowned.length) {
  failures.push(
    `R1/R3 VIOLATED — ${unowned.length} finding(s) have NO canonical owner (a finding ` +
      `disappeared): ${unowned.slice(0, 20).join(', ')}`,
  )
}
if (ownedNotInSource.length) {
  failures.push(
    `R1 VIOLATED — ${ownedNotInSource.length} owned id(s) are not in the source ` +
      `register (invented): ${ownedNotInSource.slice(0, 20).join(', ')}`,
  )
}
if (sourceSet.size !== ownedIds.size) {
  failures.push(
    `R1 VIOLATED — accounting does not balance: source=${sourceSet.size} ` +
      `canonicallyOwned=${ownedIds.size}`,
  )
}

// R6 — certification states preserved verbatim.
const stateBySource = new Map(clean.map((f) => [f.id, f.state]))
const promoted = []
for (const ch of chapters) {
  for (const rec of ch.findingStates || []) {
    const was = stateBySource.get(rec.id)
    if (was && rec.state && rec.state !== was) {
      promoted.push(`${rec.id}: ${was} -> ${rec.state}`)
    }
  }
}
if (promoted.length) {
  failures.push(`R6 VIOLATED — finding state changed by analysis: ${promoted.join('; ')}`)
}

// R4 — every C0..C11 chapter represented or explicitly excluded with evidence.
const C_ALL = Array.from({ length: 12 }, (_, i) => `C${i}`)
const cCovered = new Set()
for (const ch of chapters) for (const c of ch.cRelationship || []) cCovered.add(c)
const cMissing = C_ALL.filter((c) => !cCovered.has(c))
const cExcluded = new Set((portfolio.explicitlyExcludedChapters || []).map((e) => e.id || e))
const cUnaccounted = cMissing.filter((c) => !cExcluded.has(c))
if (cUnaccounted.length) {
  failures.push(
    `R4 VIOLATED — reconstruction chapters absent from the portfolio and not ` +
      `explicitly excluded: ${cUnaccounted.join(', ')}`,
  )
}

// R5 — WG traceability.
const wgIds = new Set(wg.filter((w) => !w.__malformed && w.id).map((w) => w.id))
const wgAbsorbed = new Set()
for (const ch of chapters) for (const w of ch.wgAbsorbed || []) wgAbsorbed.add(w)
const wgDeferred = new Set((portfolio.deferredWg || []).map((d) => d.id || d))
const wgLost = [...wgIds].filter((w) => !wgAbsorbed.has(w) && !wgDeferred.has(w))
if (wgLost.length) {
  failures.push(`R5 VIOLATED — WG item(s) neither absorbed nor deferred: ${wgLost.join(', ')}`)
}

// R8 — founder decisions must survive as decisions.
const decisionCount = chapters.reduce((n, ch) => n + (ch.founderDecisions || []).length, 0)
if (decisionCount === 0) {
  warnings.push(
    'R8 — no founder decisions recorded anywhere in the portfolio. Verify none were ' +
      'silently converted into engineering assumptions.',
  )
}

// R9 — anomalies must be reported, never repaired.
const reported = {
  duplicatesInSource,
  missingIds: anomalies.missingIds || [],
  malformedRecords: malformed.length,
  weakEvidenceIds: anomalies.weakEvidenceIds || [],
  contradictoryStates: anomalies.contradictoryStates || [],
}

// Chapter-size sanity: has a chapter merely renamed the dump?
const oversized = chapters
  .filter((ch) => (ch.canonicalFindings || []).length > Math.ceil(sourceSet.size * 0.25))
  .map((ch) => `${ch.id} (${ch.canonicalFindings.length})`)
if (oversized.length) {
  warnings.push(
    `Chapter(s) own >25% of all findings and may be a backlog bucket rather than a ` +
      `reconstruction system: ${oversized.join(', ')}`,
  )
}

// ── Optional delta vs a previous run ────────────────────────────────────────
let delta = null
if (compareRoot) {
  const prevPath = join(compareRoot, '03-synthesis', 'portfolio.json')
  const prevFindingsPath = join(compareRoot, '00-evidence', 'findings.jsonl')
  if (existsSync(prevPath) && existsSync(prevFindingsPath)) {
    const prev = readJson(prevPath)
    const prevFindings = readJsonl(prevFindingsPath).filter((f) => !f.__malformed && f.id)
    const prevIds = new Set(prevFindings.map((f) => f.id))
    const prevState = new Map(prevFindings.map((f) => [f.id, f.state]))
    const prevChapters = new Set((prev.chapters || []).map((c) => c.id))
    const nowChapters = new Set(chapters.map((c) => c.id))
    delta = {
      newFindings: [...sourceSet].filter((id) => !prevIds.has(id)),
      removedFromSource: [...prevIds].filter((id) => !sourceSet.has(id)),
      stateTransitions: clean
        .filter((f) => prevState.has(f.id) && prevState.get(f.id) !== f.state)
        .map((f) => ({ id: f.id, from: prevState.get(f.id), to: f.state })),
      chaptersOpened: [...nowChapters].filter((c) => !prevChapters.has(c)),
      chaptersClosed: [...prevChapters].filter((c) => !nowChapters.has(c)),
      unresolvedSystemCount: {
        previous: (prev.chapters || []).filter((c) => c.maturity !== 'COMPLETE').length,
        current: chapters.filter((c) => c.maturity !== 'COMPLETE').length,
      },
    }
  } else {
    warnings.push(`--compare given but previous run artifacts not found at ${compareRoot}`)
  }
}

// ── Emit ────────────────────────────────────────────────────────────────────
const result = {
  runRoot,
  generatedFrom: { findingsPath, portfolioPath },
  totals: {
    sourceFindings: sourceSet.size,
    canonicallyOwned: ownedIds.size,
    balances: sourceSet.size === ownedIds.size && !unowned.length && !ownedTwice.length,
    chapters: chapters.length,
    wgItems: wgIds.size,
    wgAbsorbed: wgAbsorbed.size,
    wgDeferred: wgDeferred.size,
  },
  invariants: {
    R1_exactlyOneOwner: !ownedTwice.length && !unowned.length && !ownedNotInSource.length,
    R3_noDisappearance: !unowned.length,
    R4_cChaptersCovered: !cUnaccounted.length,
    R5_wgTraceable: !wgLost.length,
    R6_statesPreserved: !promoted.length,
    R9_anomaliesReported: true,
  },
  reported,
  delta,
  warnings,
  failures,
  verdict: failures.length ? 'FAIL' : 'PASS',
}

mkdirSync(join(runRoot, '04-proof'), { recursive: true })
writeFileSync(join(runRoot, '04-proof', 'reconciliation.json'), JSON.stringify(result, null, 2))

console.log(`\nSOURCE FINDINGS      : ${result.totals.sourceFindings}`)
console.log(`CANONICALLY OWNED    : ${result.totals.canonicallyOwned}`)
console.log(`CHAPTERS             : ${result.totals.chapters}`)
console.log(`WG absorbed/deferred : ${result.totals.wgAbsorbed}/${result.totals.wgDeferred} of ${result.totals.wgItems}`)
for (const w of warnings) console.log(`WARN  ${w}`)
for (const f of failures) console.log(`FAIL  ${f}`)
console.log(`\nVERDICT: ${result.verdict}\n`)

process.exit(failures.length ? 1 : 0)
