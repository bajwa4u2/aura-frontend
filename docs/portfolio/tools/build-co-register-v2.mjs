#!/usr/bin/env node
/**
 * CHARTERED-OBLIGATION REGISTER v2 — CHECKPOINT-AWARE RE-EXTRACTION.
 *
 * v1 read three fields: keyFrozenOutcomes, explicitlyRemainingObligations and
 * originalScope.*. The RC-C7 Correspondence architectural-convergence verdict —
 * a NAMED FOUNDER CHECKPOINT with no recorded outcome — was recorded by Stage 0
 * in `contradictionsOrGaps`, a fourth field, and was therefore invisible to the
 * axis built precisely to stop chartered work disappearing.
 *
 * RC-C7 revealed the class; it is not treated as a one-off. v2 reads the fourth
 * field across ALL twelve chapters.
 *
 * NARRATIVE COMMENTARY IS NOT AN OBLIGATION. Only entries whose TYPE token
 * signals an unresolved required decision/disposition create obligations. The
 * rule is a documented token test, not a judgement call, so it reproduces
 * identically on every run.
 *
 * STABLE IDS ARE NON-NEGOTIABLE. Existing COs keep their ids, matched by
 * (chapter, normalised-text hash) against the v1 register. New obligations
 * continue each chapter's sequence from its existing maximum. Nothing is
 * renumbered to make the register look tidy.
 *
 * Usage: node build-co-register-v2.mjs <evidenceDir> <v1RegisterDir> <outDir>
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'
import { createHash } from 'node:crypto'

const [EV, V1DIR, OUT] = process.argv.slice(2)
if (!EV || !V1DIR || !OUT) {
  console.error('usage: node build-co-register-v2.mjs <evidenceDir> <v1RegisterDir> <outDir>')
  process.exit(2)
}
mkdirSync(OUT, { recursive: true })

const rcMap = JSON.parse(readFileSync(join(EV, 'rc-map.json'), 'utf8'))
const v1 = JSON.parse(readFileSync(join(V1DIR, 'chartered-obligation-register.json'), 'utf8'))

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

// ── v1 identity index: (chapter|hash) -> existing id ────────────────────────
const v1ById = new Map(v1.obligations.map((c) => [c.id, c]))
const v1Identity = new Map()
const maxSeq = new Map()
for (const c of v1.obligations) {
  v1Identity.set(c.rcChapter + '|' + hash(c.obligation), c.id)
  const n = parseInt(String(c.id).split('-').pop(), 10)
  maxSeq.set(c.rcChapter, Math.max(maxSeq.get(c.rcChapter) || 0, n))
}

// ── obligation-bearing type rule for the newly-read field ───────────────────
// A contradiction/gap entry becomes an obligation ONLY when its type token
// signals an unresolved required decision, disposition, void or unmet
// precondition. Everything else is commentary about the record, not future work.
const OBLIGATION_TOKENS = ['UNRESOLVED', 'OPEN_', 'VOID', 'UNASSIGNED', 'UNADDRESSED', 'UNMET', 'DISPOSITION']
const isObligationBearing = (type) => {
  const t = String(type || '').toUpperCase()
  return OBLIGATION_TOKENS.some((tok) => t.includes(tok))
}

const TYPE_BY_FIELD = {
  keyFrozenOutcomes: 'FROZEN_OUTCOME',
  explicitlyRemainingObligations: 'REMAINING_OBLIGATION',
  originalScope: 'CHARTERED_SCOPE',
  contradictionsOrGaps: 'UNRESOLVED_CHECKPOINT',
}

const inputs = []
const cos = []
const rejectedCommentary = []
const seenIdentity = new Set()

for (const ch of rcMap.chapters) {
  const rc = ch.id
  const fam = []
  for (const f of ['keyFrozenOutcomes', 'explicitlyRemainingObligations']) {
    ;(ch[f] || []).forEach((v, i) => fam.push({ field: f, path: `${rc}.${f}[${i}]`, value: v }))
  }
  const scope = ch.originalScope || {}
  for (const key of Object.keys(scope)) {
    const v = scope[key]
    if (Array.isArray(v)) v.forEach((x, i) => fam.push({ field: 'originalScope', path: `${rc}.originalScope.${key}[${i}]`, subScope: key, value: x }))
  }
  // NEW in v2 — the field that hid the RC-C7 checkpoint.
  ;(ch.contradictionsOrGaps || []).forEach((g, i) => {
    const type = (g && g.type) || 'RAW'
    const entry = { field: 'contradictionsOrGaps', path: `${rc}.contradictionsOrGaps[${i}]`, subScope: type, value: g }
    if (isObligationBearing(type)) fam.push(entry)
    else rejectedCommentary.push({ rcChapter: rc, path: entry.path, type, reason: 'type token does not signal an unresolved required decision', text: norm(asText(g)).slice(0, 200) })
  })

  for (const item of fam) {
    const text = norm(asText(item.value))
    const identity = rc + '|' + hash(text)
    const inputId = `IN:${item.path}`

    if (seenIdentity.has(identity)) {
      inputs.push({ inputId, rcChapter: rc, sourceField: item.field, sourcePath: item.path,
        disposition: 'MERGED_INTO', coId: v1Identity.get(identity) || null, text })
      continue
    }
    seenIdentity.add(identity)

    let coId = v1Identity.get(identity)
    const isNew = !coId
    if (isNew) {
      const n = (maxSeq.get(rc) || 0) + 1
      maxSeq.set(rc, n)
      coId = `CO-${rc}-${String(n).padStart(3, '0')}`
    }

    const prior = v1ById.get(coId)
    const relatedFromText = [...new Set((text.match(/\bF\d{3}\b/g) || []))].filter((f) => Number(f.slice(1)) <= 143)

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
      implementationEvidence: prior ? prior.implementationEvidence : 'NOT_RECORDED',
      validationRequirement: prior ? prior.validationRequirement : 'NOT_RECORDED',
      dependencyOrGate: prior ? prior.dependencyOrGate : 'NOT_RECORDED',
      protectedBoundaryImplications: prior ? prior.protectedBoundaryImplications : 'NOT_RECORDED',
      currentOwner: prior ? prior.currentOwner : 'NOT_RECORDED',
      futureImplementationChapterOwner: prior ? prior.futureImplementationChapterOwner : 'NOT_ASSIGNED',
      relatedFindings: relatedFromText,
      zeroFindingCoverage: relatedFromText.length === 0,
      unresolvedDecision: null,
      registerVersion: isNew ? 'v2-new' : 'v1-preserved',
    })

    inputs.push({ inputId, rcChapter: rc, sourceField: item.field, sourcePath: item.path,
      disposition: isNew ? 'PROMOTED_NEW' : 'PROMOTED_PRESERVED', coId, text })
  }
}

// ── original-299 disposition ledger ─────────────────────────────────────────
const finalIds = new Set(cos.map((c) => c.id))
const originalDisposition = v1.obligations.map((c) => ({
  id: c.id,
  rcChapter: c.rcChapter,
  disposition: finalIds.has(c.id) ? 'PRESERVED' : 'DROPPED_UNEXPECTED',
  note: finalIds.has(c.id)
    ? 'Identity matched by (chapter, normalised text). Id stable; never renumbered.'
    : 'NOT PRESERVED — this must never happen without an explicit founder ruling.',
}))
const preserved = originalDisposition.filter((d) => d.disposition === 'PRESERVED').length
const dropped = originalDisposition.filter((d) => d.disposition !== 'PRESERVED')
const newCos = cos.filter((c) => c.registerVersion === 'v2-new')

const perChapter = {}
for (const c of cos) {
  perChapter[c.rcChapter] = perChapter[c.rcChapter] || { total: 0, v1: 0, new: 0 }
  perChapter[c.rcChapter].total++
  perChapter[c.rcChapter][c.registerVersion === 'v2-new' ? 'new' : 'v1']++
}

const register = {
  artifact: 'CHARTERED_OBLIGATION_REGISTER',
  version: 'v2-checkpoint-aware',
  axis: 'AXIS_2_CHARTERED_OBLIGATION_COVERAGE',
  type: 'ANALYTICAL_PROPOSAL',
  date: '2026-08-18',
  supersedes: 'v1 (299 obligations, three source fields) — preserved as history, not deleted',
  extraction: {
    sourceFields: Object.keys(TYPE_BY_FIELD),
    newInV2: 'contradictionsOrGaps, filtered by the obligation-bearing type rule',
    obligationBearingTypeRule: OBLIGATION_TOKENS,
    ruleRationale: 'Narrative commentary about the record is not a future obligation. Only an unresolved required decision, disposition, void or unmet precondition creates one.',
    rawInputs: inputs.length,
    promotedPreserved: inputs.filter((i) => i.disposition === 'PROMOTED_PRESERVED').length,
    promotedNew: inputs.filter((i) => i.disposition === 'PROMOTED_NEW').length,
    mergedDuplicates: inputs.filter((i) => i.disposition === 'MERGED_INTO').length,
    rejectedAsCommentary: rejectedCommentary.length,
    rejectionPolicy: 'Commentary rejection is MECHANICAL and reproducible via the type-token rule. Judging a CHARTER CLAUSE to be a non-obligation remains a founder decision and is still not permitted.',
  },
  original299Disposition: {
    input: v1.obligations.length,
    preserved,
    reclassified: 0,
    merged: 0,
    superseded: 0,
    dropped: dropped.length,
    note: 'No original CO may silently disappear. Ids are stable and were never renumbered.',
  },
  totals: {
    chapters: rcMap.chapters.length,
    charteredObligations: cos.length,
    carriedFromV1: cos.length - newCos.length,
    newlyDiscovered: newCos.length,
    zeroFindingObligations: cos.filter((c) => c.zeroFindingCoverage).length,
  },
  perChapter,
  newlyDiscovered: newCos.map((c) => ({ id: c.id, rcChapter: c.rcChapter, obligationType: c.obligationType, scopeArea: c.scopeArea, obligation: c.obligation, provenance: c.provenance })),
  rejectedCommentary,
  obligations: cos,
}

writeFileSync(join(OUT, 'chartered-obligation-register-v2.json'), JSON.stringify(register, null, 1))
writeFileSync(join(OUT, 'co-input-dispositions-v2.json'), JSON.stringify({
  artifact: 'CO_INPUT_DISPOSITION_LEDGER_V2',
  invariant: 'Every raw charter candidate has an explicit disposition, and every original-299 CO has an explicit disposition. Nothing may be dropped.',
  rawInputs: inputs.length,
  dispositions: inputs,
  original299Disposition: originalDisposition,
}, null, 1))

console.log(`raw candidates        : ${inputs.length}  (v1 read ${v1.extraction.rawInputs})`)
console.log(`  preserved from v1   : ${register.extraction.promotedPreserved}`)
console.log(`  NEWLY DISCOVERED    : ${register.extraction.promotedNew}`)
console.log(`  merged duplicates   : ${register.extraction.mergedDuplicates}`)
console.log(`  rejected commentary : ${register.extraction.rejectedAsCommentary}`)
console.log(`\nORIGINAL 299 -> preserved ${preserved} / dropped ${dropped.length}`)
console.log(`FINAL CO TOTAL        : ${cos.length}`)
for (const c of newCos) console.log(`  NEW ${c.id}  [${c.scopeArea}]  ${c.obligation.slice(0, 96)}`)
