#!/usr/bin/env node
/**
 * STAGE 0 — DETERMINISTIC IDENTIFIER ACCOUNTING.
 *
 * Computes the register accounting rather than asserting it, and — critically —
 * excludes SELF-CONTAMINATION.
 *
 * Self-contamination is real and was caught in this run: the workflow-design
 * session printed lists of candidate/missing F-ids, that output was written to
 * the session transcript, and the transcript is inside the corpus being mined.
 * Re-reading it manufactures "evidence" for identifiers that were never issued
 * (F144..F159 each appeared exactly twice, all from one enumeration; F200, F214,
 * F990 likewise). Any id evidenced ONLY by self-authored sources is therefore
 * quarantined, never counted as issued.
 *
 * Usage: node reconcile-ids.mjs <evidenceDir> <selfSessionId>
 * Writes: <evidenceDir>/id-accounting.json
 */

import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const [dir, selfSession] = process.argv.slice(2)
if (!dir) { console.error('usage: node reconcile-ids.mjs <evidenceDir> <selfSessionId>'); process.exit(2) }

const recs = readFileSync(join(dir, 'mentions.jsonl'), 'utf8')
  .split(/\r?\n/).filter(Boolean).map((l) => JSON.parse(l))

// Sources authored BY this workflow-design effort, which cannot testify about
// what the project historically issued.
const isSelfAuthored = (r) =>
  (selfSession && r.source.startsWith(selfSession)) ||
  /docs[\\/]portfolio[\\/]/.test(r.source)

const byId = new Map()
for (const r of recs) {
  if (!byId.has(r.id)) byId.set(r.id, { id: r.id, total: 0, external: 0, self: 0, docs: 0, transcripts: 0, stateHints: 0, issueHints: 0, sources: new Set() })
  const e = byId.get(r.id)
  e.total++
  if (isSelfAuthored(r)) e.self++
  else {
    e.external++
    e.sources.add(r.source)
    if (r.family === 'governed-doc') e.docs++
    else e.transcripts++
    if (r.hasStateHint) e.stateHints++
    if (r.hasIssueHint) e.issueHints++
  }
}

const rows = [...byId.values()].map((e) => ({
  id: e.id,
  total: e.total,
  externalMentions: e.external,
  selfAuthoredMentions: e.self,
  inGovernedDocs: e.docs,
  inTranscripts: e.transcripts,
  distinctExternalSources: e.sources.size,
  stateHintMentions: e.stateHints,
  issuanceHintMentions: e.issueHints,
  classification:
    e.external === 0 ? 'QUARANTINED_SELF_AUTHORED_ONLY'
    : e.external <= 2 ? 'ISSUED_WEAK_EVIDENCE'
    : 'ISSUED',
  provenanceStrength:
    e.external === 0 ? 'NONE'
    : e.external <= 2 ? 'WEAK'
    : e.external <= 6 ? 'MODERATE'
    : 'STRONG',
})).sort((a, b) => a.id.localeCompare(b.id))

const fRows = rows.filter((r) => r.id.startsWith('F'))
const wgRows = rows.filter((r) => r.id.startsWith('WG'))

const issuedF = fRows.filter((r) => r.classification !== 'QUARANTINED_SELF_AUTHORED_ONLY')
const quarantinedF = fRows.filter((r) => r.classification === 'QUARANTINED_SELF_AUTHORED_ONLY')
const issuedNums = issuedF.map((r) => parseInt(r.id.slice(1), 10)).sort((a, b) => a - b)
const maxIssued = issuedNums.length ? issuedNums[issuedNums.length - 1] : 0
const gaps = []
for (let i = 1; i <= maxIssued; i++) if (!issuedNums.includes(i)) gaps.push(`F${String(i).padStart(3, '0')}`)

const issuedWg = wgRows.filter((r) => r.classification !== 'QUARANTINED_SELF_AUTHORED_ONLY')
const wgNums = issuedWg.map((r) => parseInt(r.id.slice(2), 10)).sort((a, b) => a - b)
const wgMax = wgNums.length ? wgNums[wgNums.length - 1] : 0
const wgGaps = []
for (let i = 1; i <= wgMax; i++) if (!wgNums.includes(i)) wgGaps.push(`WG${String(i).padStart(3, '0')}`)

const out = {
  method: 'Deterministic. Mentions extracted once from the full corpus, deduplicated by normalised context, base64/hash neighbourhoods rejected, self-authored sources quarantined.',
  selfContaminationGuard: {
    selfSessionTranscript: selfSession || null,
    alsoExcluded: 'any source under docs/portfolio/ (this workflow-design effort)',
    rationale: 'The design session printed candidate and missing id lists; that output entered the transcript corpus. Counting it would manufacture issuance evidence for identifiers that were never issued.',
    quarantinedIds: quarantinedF.map((r) => r.id).concat(wgRows.filter((r) => r.classification === 'QUARANTINED_SELF_AUTHORED_ONLY').map((r) => r.id)),
  },
  findings: {
    issuedCount: issuedF.length,
    highestIssuedId: maxIssued ? `F${String(maxIssued).padStart(3, '0')}` : null,
    identifierRange: maxIssued ? `F001-F${String(maxIssued).padStart(3, '0')}` : null,
    identifierSpaceSize: maxIssued,
    gapsWithinRange: gaps,
    contiguous: gaps.length === 0,
    byProvenanceStrength: {
      STRONG: issuedF.filter((r) => r.provenanceStrength === 'STRONG').length,
      MODERATE: issuedF.filter((r) => r.provenanceStrength === 'MODERATE').length,
      WEAK: issuedF.filter((r) => r.provenanceStrength === 'WEAK').length,
    },
    weakEvidenceIds: issuedF.filter((r) => r.provenanceStrength === 'WEAK').map((r) => r.id),
    evidencedInGovernedDocs: issuedF.filter((r) => r.inGovernedDocs > 0).length,
    evidencedOnlyInTranscripts: issuedF.filter((r) => r.inGovernedDocs === 0).length,
  },
  wg: {
    issuedCount: issuedWg.length,
    highestIssuedId: wgMax ? `WG${String(wgMax).padStart(3, '0')}` : null,
    gapsWithinRange: wgGaps,
    weakEvidenceIds: issuedWg.filter((r) => r.provenanceStrength === 'WEAK').map((r) => r.id),
  },
  rows,
}

writeFileSync(join(dir, 'id-accounting.json'), JSON.stringify(out, null, 2))

console.log(`SELF-CONTAMINATION quarantined ids : ${out.selfContaminationGuard.quarantinedIds.length}`)
console.log(`  ${out.selfContaminationGuard.quarantinedIds.join(', ')}`)
console.log(`\nISSUED FINDINGS                    : ${out.findings.issuedCount}`)
console.log(`identifier range                   : ${out.findings.identifierRange}`)
console.log(`gaps within range                  : ${gaps.length ? gaps.join(', ') : 'NONE (contiguous)'}`)
console.log(`provenance STRONG/MODERATE/WEAK    : ${out.findings.byProvenanceStrength.STRONG}/${out.findings.byProvenanceStrength.MODERATE}/${out.findings.byProvenanceStrength.WEAK}`)
console.log(`evidenced in governed docs         : ${out.findings.evidencedInGovernedDocs}`)
console.log(`evidenced ONLY in transcripts      : ${out.findings.evidencedOnlyInTranscripts}`)
console.log(`\nISSUED WG                          : ${out.wg.issuedCount} (max ${out.wg.highestIssuedId}, gaps: ${wgGaps.length ? wgGaps.join(', ') : 'none'})`)
