#!/usr/bin/env node
/**
 * STAGE 0 — DETERMINISTIC MENTION EXTRACTION.
 *
 * Scripts prove bookkeeping; models reconstruct meaning. This pass does ALL the
 * corpus scanning exactly once so no agent ever re-reads 745 MB, and so the
 * identifier accounting is computed rather than asserted.
 *
 * Streams every source line, finds F-id / WG-id references, captures a context
 * window around each, classifies base64 false positives, deduplicates repeated
 * context (transcripts re-quote each other heavily), and writes:
 *
 *   source-inventory.json   every file scanned, size, mtime, match counts
 *   mentions.jsonl          one record per surviving distinct mention
 *   extraction-stats.json   accounting: accepted / rejected / dedup ratios
 *
 * READ-ONLY with respect to every source. Resumable: skips work if outputs
 * exist and --force is absent.
 */

import { createReadStream, existsSync, readFileSync, writeFileSync, mkdirSync, statSync, createWriteStream } from 'node:fs'
import { createInterface } from 'node:readline'
import { join, basename } from 'node:path'
import { createHash } from 'node:crypto'

const OUT = process.argv[2]
const FORCE = process.argv.includes('--force')
if (!OUT) { console.error('usage: node extract-mentions.mjs <outDir> [--force]'); process.exit(2) }
mkdirSync(OUT, { recursive: true })

const TRANSCRIPTS = 'C:/Users/muham/.claude/projects/C--Users-muham-flutter-projects'
const DOC_ROOTS = [
  'C:/Users/muham/flutter_projects/aura/aura_final/docs',
  'C:/Users/muham/flutter_projects/aura/aura-backend/docs',
  'C:/Users/muham/flutter_projects/aura/aura-backend/capability',
  'C:/Users/muham/flutter_projects/aura/docs',
]

const mentionsPath = join(OUT, 'mentions.jsonl')
if (existsSync(mentionsPath) && !FORCE) {
  console.log(`mentions.jsonl already present — resuming without re-scan (use --force to redo)`)
  process.exit(0)
}

// ── source inventory ────────────────────────────────────────────────────────
import { readdirSync } from 'node:fs'
function walk(dir, acc = []) {
  let entries = []
  try { entries = readdirSync(dir, { withFileTypes: true }) } catch { return acc }
  for (const e of entries) {
    const p = join(dir, e.name)
    if (e.isDirectory()) {
      if (/node_modules|\.git|build|dist|\.dart_tool/.test(e.name)) continue
      walk(p, acc)
    } else if (/\.(md|jsonl)$/i.test(e.name)) acc.push(p)
  }
  return acc
}

const sources = []
for (const f of readdirSync(TRANSCRIPTS)) {
  if (f.endsWith('.jsonl')) sources.push({ path: join(TRANSCRIPTS, f), family: 'session-transcript' })
}
for (const root of DOC_ROOTS) for (const p of walk(root)) sources.push({ path: p, family: 'governed-doc' })

console.log(`sources: ${sources.length} (${sources.filter(s=>s.family==='session-transcript').length} transcripts, ${sources.filter(s=>s.family==='governed-doc').length} docs)`)

// ── matching ────────────────────────────────────────────────────────────────
// Word-bounded F-id / WG-id. Context window is generous enough for an agent to
// judge meaning without opening the source.
const ID_RE = /\b(F\d{3}|WG-?\d{1,3})\b/g
const WIN = 320

/**
 * Base64 / hash false-positive detector.
 * A genuine reference sits in prose. A false positive sits inside a long
 * unbroken run of base64-ish characters. Measured on the neighbourhood rather
 * than the token, because the token itself is identical in both cases.
 */
function looksLikeEncodedBlob(ctx, idxInCtx) {
  const a = Math.max(0, idxInCtx - 60)
  const b = Math.min(ctx.length, idxInCtx + 60)
  const near = ctx.slice(a, b)
  const longRun = /[A-Za-z0-9+/=]{40,}/.test(near)
  const spaceRatio = (near.match(/\s/g) || []).length / Math.max(1, near.length)
  return longRun && spaceRatio < 0.06
}

const STATE_HINTS = /\b(OPEN|CLOSED|CERTIFIED|IMPLEMENTED|NOT_LIVE|NOT LIVE|SUPERSEDED|RETIRED|BLOCKED|RESOLVED|CONFIRMED|PARTIALLY|VALIDATED|OWNED|FIXED|PENDING|DEFERRED|ratif|freeze|frozen|ruling)\b/i
const ISSUE_HINTS = /\b(new finding|finding|defect|raised|opened|discovered|issue[sd]?)\b/i

const out = createWriteStream(mentionsPath, { encoding: 'utf8' })
const seenCtx = new Set()
const inventory = []
const stats = { scannedFiles: 0, scannedLines: 0, rawMatches: 0, rejectedEncoded: 0, dedupDropped: 0, kept: 0, bytes: 0 }
const perId = new Map()

for (const src of sources) {
  let size = 0, mtime = null
  try { const st = statSync(src.path); size = st.size; mtime = st.mtime.toISOString() } catch {}
  stats.bytes += size
  let fileMatches = 0, fileKept = 0, lineNo = 0

  const rl = createInterface({ input: createReadStream(src.path, { encoding: 'utf8' }), crlfDelay: Infinity })
  for await (const line of rl) {
    lineNo++
    stats.scannedLines++
    if (line.length > 4_000_000) continue
    ID_RE.lastIndex = 0
    let m
    while ((m = ID_RE.exec(line)) !== null) {
      stats.rawMatches++; fileMatches++
      const raw = m[1]
      const id = raw.startsWith('WG') ? 'WG' + String(parseInt(raw.replace(/^WG-?/, ''), 10)).padStart(3, '0') : raw
      const s = Math.max(0, m.index - WIN)
      const ctx = line.slice(s, Math.min(line.length, m.index + WIN))
      if (looksLikeEncodedBlob(ctx, m.index - s)) { stats.rejectedEncoded++; continue }

      const norm = ctx.replace(/\s+/g, ' ').trim()
      const key = id + '|' + createHash('sha1').update(norm).digest('hex').slice(0, 16)
      if (seenCtx.has(key)) { stats.dedupDropped++; continue }
      seenCtx.add(key)

      const rec = {
        id,
        family: src.family,
        source: src.family === 'session-transcript' ? basename(src.path) : src.path.replace(/^.*aura[\/\\]/, 'aura/'),
        line: lineNo,
        context: norm.slice(0, 640),
        hasStateHint: STATE_HINTS.test(norm),
        hasIssueHint: ISSUE_HINTS.test(norm),
      }
      out.write(JSON.stringify(rec) + '\n')
      stats.kept++; fileKept++
      perId.set(id, (perId.get(id) || 0) + 1)
    }
  }
  stats.scannedFiles++
  inventory.push({ path: src.path, family: src.family, bytes: size, mtime, rawMatches: fileMatches, keptMentions: fileKept })
  if (stats.scannedFiles % 5 === 0) console.log(`  scanned ${stats.scannedFiles}/${sources.length} files, kept ${stats.kept} mentions`)
}
out.end()

const ids = [...perId.entries()].sort((a, b) => a[0].localeCompare(b[0]))
writeFileSync(join(OUT, 'source-inventory.json'), JSON.stringify({ generatedFor: OUT, sources: inventory }, null, 2))
writeFileSync(join(OUT, 'extraction-stats.json'), JSON.stringify({
  stats,
  corpusBytes: stats.bytes,
  distinctIds: ids.length,
  mentionsPerId: Object.fromEntries(ids),
}, null, 2))

console.log(`\nfiles=${stats.scannedFiles} lines=${stats.scannedLines} bytes=${(stats.bytes/1e6).toFixed(0)}MB`)
console.log(`raw=${stats.rawMatches} rejectedEncoded=${stats.rejectedEncoded} dedupDropped=${stats.dedupDropped} kept=${stats.kept}`)
console.log(`distinct ids=${ids.length}`)
