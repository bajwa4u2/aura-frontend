#!/usr/bin/env node
/**
 * STAGE 0 — EVIDENCE DOSSIER BUILDER.
 *
 * Turns 2,588 raw mentions into one compact dossier per identifier, so the
 * semantic-reconstruction agents read a few hundred KB instead of 703 MB.
 * This is the "deduplicate extraction before semantic reconstruction" rule made
 * mechanical.
 *
 * Selection is priority-based, not truncation: governed-doc mentions outrank
 * transcripts, issuance and state hints outrank incidental references, and the
 * first and last external mentions are always retained so an agent can see both
 * issuance and latest evidenced state.
 *
 * Usage: node build-dossiers.mjs <evidenceDir> <selfSessionId> [perIdCap]
 * Writes: <evidenceDir>/dossiers/<BATCH>.json  and dossier-index.json
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'

const [dir, selfSession, capArg] = process.argv.slice(2)
const CAP = Number(capArg || 10)
if (!dir) { console.error('usage: node build-dossiers.mjs <evidenceDir> <selfSessionId> [perIdCap]'); process.exit(2) }

const recs = readFileSync(join(dir, 'mentions.jsonl'), 'utf8')
  .split(/\r?\n/).filter(Boolean).map((l) => JSON.parse(l))

const isSelfAuthored = (r) =>
  (selfSession && r.source.startsWith(selfSession)) || /docs[\\/]portfolio[\\/]/.test(r.source)

const accounting = JSON.parse(readFileSync(join(dir, 'id-accounting.json'), 'utf8'))
const issued = new Set(accounting.rows.filter((r) => r.classification !== 'QUARANTINED_SELF_AUTHORED_ONLY').map((r) => r.id))

const byId = new Map()
for (const r of recs) {
  if (isSelfAuthored(r) || !issued.has(r.id)) continue
  if (!byId.has(r.id)) byId.set(r.id, [])
  byId.get(r.id).push(r)
}

function score(r) {
  let s = 0
  if (r.family === 'governed-doc') s += 100
  if (r.hasIssueHint) s += 30
  if (r.hasStateHint) s += 25
  s += Math.min(20, Math.floor(r.context.length / 40))
  return s
}

const dossiers = []
for (const [id, all] of [...byId.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
  const first = all[0]
  const last = all[all.length - 1]
  const ranked = [...all].sort((a, b) => score(b) - score(a))
  const picked = []
  const seen = new Set()
  for (const r of [first, last, ...ranked]) {
    const k = r.source + ':' + r.line + ':' + r.context.slice(0, 60)
    if (seen.has(k)) continue
    seen.add(k)
    picked.push(r)
    if (picked.length >= CAP) break
  }
  dossiers.push({
    id,
    totalExternalMentions: all.length,
    inGovernedDocs: all.filter((r) => r.family === 'governed-doc').length,
    distinctSources: new Set(all.map((r) => r.source)).size,
    provenanceStrength: (accounting.rows.find((r) => r.id === id) || {}).provenanceStrength || 'UNKNOWN',
    evidence: picked.map((r) => ({
      source: r.source,
      line: r.line,
      family: r.family,
      issuanceHint: r.hasIssueHint,
      stateHint: r.hasStateHint,
      context: r.context,
    })),
  })
}

mkdirSync(join(dir, 'dossiers'), { recursive: true })

// Split findings into three deterministic, non-overlapping batches so three
// agents never analyse the same identifier.
const fd = dossiers.filter((d) => d.id.startsWith('F'))
const wgd = dossiers.filter((d) => d.id.startsWith('WG'))
const third = Math.ceil(fd.length / 3)
const batches = [
  { name: 'findings-batch-1', items: fd.slice(0, third) },
  { name: 'findings-batch-2', items: fd.slice(third, third * 2) },
  { name: 'findings-batch-3', items: fd.slice(third * 2) },
  { name: 'wg', items: wgd },
]

const index = []
for (const b of batches) {
  const p = join(dir, 'dossiers', `${b.name}.json`)
  writeFileSync(p, JSON.stringify({ batch: b.name, count: b.items.length, dossiers: b.items }, null, 1))
  const bytes = JSON.stringify(b.items).length
  index.push({ batch: b.name, count: b.items.length, ids: b.items.map((i) => i.id), approxBytes: bytes, path: `dossiers/${b.name}.json` })
  console.log(`${b.name}: ${b.items.length} ids, ${(bytes / 1024).toFixed(0)} KB  [${b.items[0]?.id}..${b.items[b.items.length-1]?.id}]`)
}
writeFileSync(join(dir, 'dossier-index.json'), JSON.stringify({ perIdCap: CAP, batches: index }, null, 2))
