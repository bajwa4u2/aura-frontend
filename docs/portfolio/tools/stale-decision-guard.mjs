#!/usr/bin/env node
// STALE-DECISION GUARD — founder ruling, 2026-08-18.
//
//     HISTORICAL READINESS NOTE  !=  CURRENT FOUNDER DECISION STATE
//
// Origin: a Stage-5 readiness note recorded that "the group identity doctrine
// (F055 ordering, F056 group avatar treatment) does not exist and engineering
// cannot supply it." Both had been FOUNDER-RULED the day before Stage 5 was
// authored, and both were implemented. The note was written against the
// pre-ruling register row and never updated. It then propagated into a wave
// derivation as a blocker, and very nearly caused a founder decision pack to be
// prepared for a question the founder had already answered.
//
// THE RULE. Before any artifact declares an item FOUNDER_DECISION_REQUIRED, the
// claim must be reconciled against (1) the finding's canonical
// `founderDecisions`, (2) later founder rulings, and (3) operative execution
// records that supersede the earlier readiness state.
//
// WHAT THIS TOOL DOES. It reads every execution/synthesis artifact, finds
// claims that a founder decision is outstanding, extracts the finding ids those
// claims name, and reports any whose canonical record already carries a ruling.
//
// WHAT IT DELIBERATELY DOES NOT DO. It does not edit history. A stale artifact
// stays exactly as written — Stage-5 architecture is historical evidence, and
// rulings apply forward. The output is a correction to record alongside, never
// a rewrite. It also does not decide whether a ruling fully covers a claim;
// that judgement is reported for a human, because a partially-answered question
// is still a question.
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs'
import { join, resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const RUN = resolve(HERE, '../run/stage0-2026-08-18')

/** Phrases that assert an OUTSTANDING founder decision. */
const CLAIM_PATTERNS = [
  /FOUNDER_DECISION_REQUIRED/i,
  /BLOCKED_FOUNDER/i,
  /does not exist and engineering cannot supply/i,
  /founder-only/i,
  /awaiting (?:a )?founder/i,
  /needs? (?:a )?founder (?:ruling|decision)/i,
]

/** Evidence that the canonical record already carries a ruling. */
const RULED = /^\s*RULED\b|\bRULED\.\s|founder ruling|Ruling summary|RESOLVED by founder/i

function walk(dir, out = []) {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e)
    if (statSync(p).isDirectory()) walk(p, out)
    else if (p.endsWith('.json')) out.push(p)
  }
  return out
}

// ── canonical finding records ───────────────────────────────────────────────
const findings = {}
for (const b of ['1', '2', '3']) {
  const d = JSON.parse(readFileSync(resolve(RUN, `00-evidence/findings-batch-${b}.json`), 'utf8'))
  for (const f of d.findings || d) findings[f.id] = f
}
const total = Object.keys(findings).length
if (total !== 143) throw new Error('FAIL-CLOSED: expected 143 findings, got ' + total)

// ── scan for outstanding-decision claims ────────────────────────────────────
const suspects = []
for (const file of walk(RUN)) {
  // Stage-0 evidence is the canonical record itself, not a claim about it.
  if (file.replaceAll('\\', '/').includes('/00-evidence/')) continue
  const text = readFileSync(file, 'utf8')
  const lines = text.split(/\r?\n/)
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (!CLAIM_PATTERNS.some((p) => p.test(line))) continue
    const ids = [...new Set((line.match(/\bF\d{3}\b/g) || []))]
    for (const id of ids) {
      const f = findings[id]
      if (!f) continue
      const decision = typeof f.founderDecisions === 'string' ? f.founderDecisions : JSON.stringify(f.founderDecisions ?? '')
      if (!RULED.test(decision)) continue
      suspects.push({
        artifact: file.replaceAll('\\', '/').split('/stage0-2026-08-18/')[1],
        line: i + 1,
        finding: id,
        findingTitle: f.title,
        findingState: f.currentState,
        claimExcerpt: line.trim().slice(0, 200),
        canonicalRulingExcerpt: decision.slice(0, 220),
        verdict: 'CLAIM_ASSERTS_AN_OUTSTANDING_DECISION_BUT_THE_FINDING_RECORDS_A_RULING',
      })
    }
  }
}

const out = {
  type: 'STALE_DECISION_GUARD',
  rule: 'HISTORICAL READINESS NOTE != CURRENT FOUNDER DECISION STATE',
  date: '2026-08-18',
  findingsChecked: total,
  suspectsFound: suspects.length,
  suspects,
  treatment: [
    'Preserve the historical artifact UNCHANGED — it is evidence of what was known when it was written.',
    'Record the supersession/correction FORWARD, alongside it.',
    'Do NOT resurrect the founder decision.',
    'Do NOT return alternative options for a settled doctrine.',
  ],
  limits: [
    'A hit is a SUSPECT, not a verdict. A ruling may answer part of a claim and leave a real residue; only a human can judge that.',
    'Detection is textual. A claim that names no finding id, or an artifact that phrases it in words not listed here, is not caught — the guard reduces recurrence, it does not eliminate it.',
  ],
}
writeFileSync(resolve(RUN, '05-execution/stale-decision-guard-report.json'), JSON.stringify(out, null, 1))

console.log('findings checked :', total)
console.log('suspects found   :', suspects.length)
for (const s of suspects) {
  console.log(`  ${s.finding}  ${s.artifact}:${s.line}`)
  console.log(`      claim : ${s.claimExcerpt.slice(0, 110)}`)
  console.log(`      ruling: ${s.canonicalRulingExcerpt.slice(0, 110)}`)
}
console.log(suspects.length === 0 ? 'STALE-DECISION GUARD: no stale claims detected' : 'STALE-DECISION GUARD: review the suspects above')
