#!/usr/bin/env node
/**
 * STAGE-2 AMENDMENT — CHARTERED-OBLIGATION REGISTER (AXIS 2).
 *
 * Findings answer "what defect must become correct?". Charters answer "what did
 * Aura undertake, freeze, promise, demolish, migrate or validate REGARDLESS of
 * whether a defect was ever observed?". Neither axis subsumes the other, and a
 * portfolio that accounts 143/143 findings while losing RC-C8's obligations is
 * not complete — RC-C8 is the control case: a real chapter with frozen
 * authority, a demolition target and a named invariant test, and ZERO findings.
 *
 * This extractor is DETERMINISTIC on purpose. A model-generated obligation list
 * would be re-derived differently on every run, which is exactly how chartered
 * work disappears. Every obligation traces to a fixed rc-map path.
 *
 * THE 299-INPUT DISPOSITION INVARIANT: every raw candidate read from rc-map
 * receives an explicit disposition — PROMOTED or MERGED_INTO. Nothing may be
 * dropped. Rejection is deliberately NOT a mechanical option: judging a charter
 * clause to be a non-obligation is a founder call, not a script's.
 *
 * Usage: node build-co-register.mjs <evidenceDir> <outDir>
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'
import { createHash } from 'node:crypto'

const [EV, OUT] = process.argv.slice(2)
if (!EV || !OUT) { console.error('usage: node build-co-register.mjs <evidenceDir> <outDir>'); process.exit(2) }
mkdirSync(OUT, { recursive: true })

const rcMap = JSON.parse(readFileSync(join(EV, 'rc-map.json'), 'utf8'))

const asText = (v) => {
  if (typeof v === 'string') return v
  if (v && typeof v === 'object') {
    for (const k of ['obligation', 'text', 'statement', 'name', 'title', 'item', 'description', 'outcome']) {
      if (typeof v[k] === 'string') return v[k]
    }
    return JSON.stringify(v)
  }
  return String(v)
}
const norm = (s) => s.replace(/\s+/g, ' ').trim()
const hash = (s) => createHash('sha1').update(norm(s).toLowerCase()).digest('hex').slice(0, 16)

// Obligation type is derived from WHICH charter field the clause came from.
// The field is the evidence; the label must not be invented.
const TYPE_BY_FIELD = {
  keyFrozenOutcomes: 'FROZEN_OUTCOME',
  explicitlyRemainingObligations: 'REMAINING_OBLIGATION',
  originalScope: 'CHARTERED_SCOPE',
}

const inputs = []
const cos = []
const byChapterHash = new Map()
let seq = new Map()

for (const ch of rcMap.chapters) {
  const rc = ch.id
  const families = []
  for (const f of ['keyFrozenOutcomes', 'explicitlyRemainingObligations']) {
    const arr = ch[f] || []
    arr.forEach((v, i) => families.push({ field: f, path: `${rc}.${f}[${i}]`, value: v }))
  }
  const scope = ch.originalScope || {}
  for (const key of Object.keys(scope)) {
    const v = scope[key]
    if (Array.isArray(v)) v.forEach((x, i) => families.push({ field: 'originalScope', path: `${rc}.originalScope.${key}[${i}]`, subScope: key, value: x }))
  }

  for (const item of families) {
    const text = norm(asText(item.value))
    const h = hash(text)
    const key = rc + '|' + h
    const inputId = `IN:${item.path}`

    if (byChapterHash.has(key)) {
      // Exact duplicate clause within the same chapter — merged, never dropped.
      inputs.push({ inputId, rcChapter: rc, sourceField: item.field, sourcePath: item.path,
        disposition: 'MERGED_INTO', coId: byChapterHash.get(key), text })
      continue
    }

    const n = (seq.get(rc) || 0) + 1
    seq.set(rc, n)
    const coId = `CO-${rc}-${String(n).padStart(3, '0')}`
    byChapterHash.set(key, coId)

    const relatedFromText = [...new Set((text.match(/\bF\d{3}\b/g) || []))]
      .filter((f) => Number(f.slice(1)) <= 143)

    cos.push({
      id: coId,
      rcChapter: rc,
      rcChapterName: ch.historicalName,
      obligationType: TYPE_BY_FIELD[item.field] || 'CHARTERED_SCOPE',
      scopeArea: item.subScope || null,
      obligation: text,
      provenance: { artifact: '00-evidence/rc-map.json', path: item.path },
      chapterEvidencedStatus: ch.currentEvidencedStatus || null,
      currentState: 'NOT_RECORDED_AT_OBLIGATION_LEVEL',
      currentStateNote: 'Chapter-level status is recorded separately and MUST NOT be read as this obligation being satisfied.',
      implementationEvidence: 'NOT_RECORDED',
      validationRequirement: 'NOT_RECORDED',
      dependencyOrGate: 'NOT_RECORDED',
      protectedBoundaryImplications: 'NOT_RECORDED',
      currentOwner: 'NOT_RECORDED',
      futureImplementationChapterOwner: 'NOT_ASSIGNED_STAGE_3',
      relatedFindings: relatedFromText,
      zeroFindingCoverage: relatedFromText.length === 0,
      unresolvedDecision: null,
    })

    inputs.push({ inputId, rcChapter: rc, sourceField: item.field, sourcePath: item.path,
      disposition: 'PROMOTED', coId, text })
  }
}

const perChapter = {}
for (const c of cos) {
  perChapter[c.rcChapter] = perChapter[c.rcChapter] || { total: 0, zeroFinding: 0, byType: {} }
  perChapter[c.rcChapter].total++
  if (c.zeroFindingCoverage) perChapter[c.rcChapter].zeroFinding++
  perChapter[c.rcChapter].byType[c.obligationType] = (perChapter[c.rcChapter].byType[c.obligationType] || 0) + 1
}

const byType = {}
for (const c of cos) byType[c.obligationType] = (byType[c.obligationType] || 0) + 1

const register = {
  artifact: 'CHARTERED_OBLIGATION_REGISTER',
  axis: 'AXIS_2_CHARTERED_OBLIGATION_COVERAGE',
  type: 'ANALYTICAL_PROPOSAL',
  date: '2026-08-18',
  status: 'CANDIDATE — NOT FOUNDER-RATIFIED',
  principle:
    'A finding does not create a charter obligation, and a charter obligation does not require a finding to exist. ' +
    'The portfolio is complete only when BOTH populations reconcile. Related findings are CROSS-REFERENCES, never ownership equivalence.',
  extraction: {
    method: 'DETERMINISTIC. Every obligation traces to a fixed rc-map path; re-running reproduces identical ids.',
    sourceFields: Object.keys(TYPE_BY_FIELD),
    rawInputs: inputs.length,
    promoted: inputs.filter((i) => i.disposition === 'PROMOTED').length,
    mergedDuplicates: inputs.filter((i) => i.disposition === 'MERGED_INTO').length,
    rejected: 0,
    rejectionPolicy: 'Mechanical rejection is NOT permitted. Judging a charter clause to be a non-obligation is a founder decision.',
  },
  totals: {
    chapters: rcMap.chapters.length,
  },
  perChapter,
  byType,
  obligations: cos,
}
register.totals.charteredObligations = cos.length
register.totals.zeroFindingObligations = cos.filter((c) => c.zeroFindingCoverage).length
register.totals.obligationsWithRelatedFindings = cos.filter((c) => !c.zeroFindingCoverage).length

writeFileSync(join(OUT, 'chartered-obligation-register.json'), JSON.stringify(register, null, 1))
writeFileSync(join(OUT, 'co-input-dispositions.json'), JSON.stringify({
  artifact: 'CO_INPUT_DISPOSITION_LEDGER',
  invariant: 'Every raw charter candidate read from rc-map has an explicit disposition. None may be dropped.',
  rawInputs: inputs.length,
  dispositions: inputs,
}, null, 1))

console.log(`raw charter candidates : ${inputs.length}`)
console.log(`  PROMOTED             : ${register.extraction.promoted}`)
console.log(`  MERGED_INTO (dupes)  : ${register.extraction.mergedDuplicates}`)
console.log(`  REJECTED             : 0  (mechanical rejection not permitted)`)
console.log(`chartered obligations  : ${cos.length}`)
console.log(`zero-finding COs       : ${register.totals.zeroFindingObligations}`)
console.log('per chapter:')
for (const rc of rcMap.chapters.map((c) => c.id)) {
  const p = perChapter[rc]
  console.log(`  ${rc.padEnd(7)} COs=${String(p.total).padEnd(4)} zeroFinding=${p.zeroFinding}`)
}
