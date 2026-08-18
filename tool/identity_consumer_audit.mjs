#!/usr/bin/env node
// W1-F — ENUMERATED IDENTITY CONSUMER AUDIT (CH-03)
//
// READ-ONLY. CODE_STATIC. Changes no consumer, renders no image, touches no
// production data. It produces the ENUMERATED CONSUMER LIST that PB-05 names
// as F116's exit condition — F116 may NOT be closed by fixing one consumer.
//
// F053 as issued: "THE CANONICAL IDENTITY SYSTEM IS NOT BEING CONSUMED
// CONSISTENTLY ACROSS THE PRODUCT." Founder instruction: if another ad-hoc
// name/avatar/user-shape resolver is discovered, MARK IT.
//
// The audit is DELIBERATELY not a count. Every row carries its file, line and
// the evidence string, so a human can check any verdict without rerunning it.
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'

const FRONTEND = 'C:/Users/muham/flutter_projects/aura/aura_final'
const BACKEND = 'C:/Users/muham/flutter_projects/aura/aura-backend'
const OUT = 'docs/portfolio/run/stage0-2026-08-18/05-execution/w1f-identity-consumer-audit.json'

const walk = (dir, ext, acc = []) => {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e)
    const st = statSync(p)
    if (st.isDirectory()) { if (e !== 'node_modules' && e !== '.git') walk(p, ext, acc) }
    else if (e.endsWith(ext)) acc.push(p)
  }
  return acc
}
const norm = (root, p) => relative(root, p).replace(/\\/g, '/')
const windowOf = (lines, i, r = 12) =>
  lines.slice(Math.max(0, i - r), Math.min(lines.length, i + r)).join('\n')

const rows = []
const add = (r) => rows.push(r)

// ─────────────────────────────────────────────── BACKEND (aura-backend/src) ──
// Canonical authority: PERSON_IDENTITY_SELECT / PERSON_REFERENCE_SELECT and
// projectPersonIdentity / projectPersonReference (founder decision D3).
// A context-specific projection is legitimate; independently REINVENTING one
// is not — so the test is composition, not narrowness.
const AUTHORITY_FILES = ['src/common/users/person-identity.ts', 'src/common/users/person-verification.ts']
for (const f of walk(join(BACKEND, 'src'), '.ts')) {
  const path = norm(BACKEND, f)
  if (path.endsWith('.spec.ts')) continue
  const lines = readFileSync(f, 'utf8').split(/\r?\n/)
  const isAuthority = AUTHORITY_FILES.includes(path)
  for (let i = 0; i < lines.length; i++) {
    if (!/\bdisplayName\s*:\s*true\b/.test(lines[i])) continue
    const w = windowOf(lines, i)
    const composes = /PERSON_IDENTITY_SELECT|PERSON_REFERENCE_SELECT/.test(w)
    const institution = /INSTITUTION_IDENTITY_SELECT|institution\s*:\s*\{|Institution\b/.test(w)
    let verdict, why
    if (isAuthority) { verdict = 'AUTHORITY'; why = 'This file IS the canonical projection authority.' }
    else if (composes) { verdict = 'CONFORMANT'; why = 'Composes the canonical person select rather than reconstructing one.' }
    else if (institution) { verdict = 'OUT_OF_SCOPE_INSTITUTION_IDENTITY'; why = 'Institution identity has its own canonical authority (institution-identity.ts); it is not a person consumer.' }
    else { verdict = 'NON_CONFORMANT'; why = 'Hand-picks person identity fields in a select without composing PERSON_IDENTITY_SELECT / PERSON_REFERENCE_SELECT.' }
    add({ repo: 'aura-backend', surface: 'PROJECTION', path, line: i + 1, evidence: lines[i].trim().slice(0, 120), verdict, why })
  }
}

// ───────────────────────────────────────────── FRONTEND (aura_final/lib) ──
// Canonical authority: AuraAvatar (avatar) and AuraIdentitySurface (identity
// row). Certification evidence on F053 records "AuraAvatar is being consumed
// consistently"; this audit tests that claim exhaustively rather than
// sampling the surfaces that happened to be touched.
const FRONT_AUTHORITY = [
  'lib/core/ui/aura_platform_components.dart',
  'lib/core/ui/aura_identity_surface.dart',
]
for (const f of walk(join(FRONTEND, 'lib'), '.dart')) {
  const path = norm(FRONTEND, f)
  const lines = readFileSync(f, 'utf8').split(/\r?\n/)
  const isAuthority = FRONT_AUTHORITY.includes(path)
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (line.trimStart().startsWith('//')) continue

    if (/\bAuraAvatar\s*\(/.test(line)) {
      add({ repo: 'aura_final', surface: 'AVATAR', path, line: i + 1, evidence: line.trim().slice(0, 120),
        verdict: isAuthority ? 'AUTHORITY' : 'CONFORMANT',
        why: isAuthority ? 'Definition site of the canonical avatar.' : 'Renders the canonical AuraAvatar.' })
    }

    if (/\bAuraIdentitySurface\s*\(/.test(line)) {
      add({ repo: 'aura_final', surface: 'IDENTITY_ROW', path, line: i + 1, evidence: line.trim().slice(0, 120),
        verdict: isAuthority ? 'AUTHORITY' : 'CONFORMANT',
        why: isAuthority ? 'Definition site of the canonical identity row.' : 'Renders the canonical identity surface.' })
    }

    if (/\bCircleAvatar\s*\(/.test(line)) {
      const w = windowOf(lines, i, 8)
      // A CircleAvatar carrying a person's image or initial is an ad-hoc
      // avatar resolver. One carrying only an Icon is decoration.
      const personBearing = /backgroundImage|NetworkImage|avatarUrl|photoUrl|imageUrl|displayName|initial|\.name\b/.test(w)
      add({ repo: 'aura_final', surface: 'AVATAR', path, line: i + 1, evidence: line.trim().slice(0, 120),
        verdict: personBearing ? 'NON_CONFORMANT' : 'NOT_AN_IDENTITY_CONSUMER',
        why: personBearing
          ? 'Renders a person image/initial through CircleAvatar instead of the canonical AuraAvatar.'
          : 'CircleAvatar used as decoration (icon only); it resolves no person identity.' })
    }

    // Ad-hoc user-shape extraction: person identity fields read straight off a
    // raw map. This is the F057 class of defect (me[id] vs me[user][id]).
    //
    // Two materially different things share this signature and must NOT be
    // reported as one number. Deserialising a person inside a model or
    // repository is the legitimate typed boundary — every client needs one
    // somewhere. Reading the same raw map inside a WIDGET is a surface
    // resolving identity for itself, which is the defect F053 names.
    const m = line.match(/\['(displayName|avatarUrl|handle|fullName|photoUrl)'\]/)
    if (m && !isAuthority) {
      const isTypedBoundary =
        /\/(domain|data)\//.test(path) ||
        /_repository\.dart$|_models?\.dart$|_model\.dart$/.test(path)
      add({ repo: 'aura_final', surface: 'USER_SHAPE', path, line: i + 1, evidence: line.trim().slice(0, 120),
        verdict: isTypedBoundary ? 'TYPED_DESERIALIZATION_BOUNDARY' : 'ADHOC_MAP_EXTRACTION_IN_SURFACE',
        why: isTypedBoundary
          ? `Deserialises the person field '${m[1]}' inside a model/repository. Legitimate as a boundary — but it is a PRIVATE person shape, so it is enumerated: the client has no single canonical identity model the way the backend now has PERSON_IDENTITY_SELECT.`
          : `A presentation surface reads the person field '${m[1]}' straight off an untyped map. This is the F057 class of defect and the direct subject of F053.` })
    }
  }
}

// ── Reconciliation of the six person-shaped extraction sites (CO-RC-C2-010) ──
const SIX = [
  { site: 'conversations_screen', declaredOwner: 'C4-retired', match: /conversations_screen\.dart$/ },
  { site: 'correspondence_hub', declaredOwner: 'C7', match: /correspondence.*hub.*\.dart$/i },
  { site: 'correspondence space', declaredOwner: 'C7', match: /(space|spaces).*\.dart$/i },
  { site: 'invite_member', declaredOwner: 'C7', match: /invite_member.*\.dart$/i },
  { site: 'member_home', declaredOwner: 'C3', match: /member_home_screen\.dart$/ },
  { site: 'admin_institution_members', declaredOwner: 'PD-1', match: /admin_institution_members.*\.dart$/i },
]
const six = SIX.map((s) => {
  const hits = rows.filter((r) => r.repo === 'aura_final' && s.match.test(r.path))
  const nonConf = hits.filter((r) => r.verdict === 'NON_CONFORMANT' || r.verdict === 'ADHOC_MAP_EXTRACTION_IN_SURFACE')
  return {
    ...s, match: String(s.match),
    sitesFoundInAudit: hits.length,
    nonConformantOrAdhoc: nonConf.length,
    files: [...new Set(hits.map((r) => r.path))],
    reconciliation: hits.length === 0
      ? 'NO_IDENTITY_CONSUMER_SIGNAL_REMAINS — a file matching this name exists in the tree but carries no avatar, no name/handle/avatarUrl map read, and no canonical identity widget. The person-shaped extraction recorded in CO-RC-C2-010 is no longer present.'
      : 'LOCATED',
    whatIsNotProven: hits.length === 0
      ? 'A static scan showing no signal does NOT prove the site was converted to canonical consumption. The surface may simply no longer present people, or may consume identity through a typed model declared elsewhere. CH-03 confirms at W2; this audit records the observation only.'
      : null,
  }
})

const tally = (pred) => rows.filter(pred).length
const byVerdict = {}
for (const r of rows) byVerdict[r.verdict] = (byVerdict[r.verdict] || 0) + 1

const out = {
  type: 'W1F_ENUMERATED_IDENTITY_CONSUMER_AUDIT',
  unit: 'W1-F',
  chapter: 'CH-03',
  date: '2026-08-18',
  status: 'AUDIT_COMPLETE_NO_CONSUMER_CHANGED',
  findingsAddressed: {
    F116: 'PARTIALLY_VALIDATED — NOT closed by this audit. PB-05 names an ENUMERATED consumer list as the exit condition; this artifact is that INPUT, not the closure.',
    F053: 'PARTIALLY_VALIDATED — NOT closed. This audit supplies the "full consumer audit" the register recorded as outstanding.',
  },
  method: {
    frontendAuthority: ['AuraAvatar', 'AuraIdentitySurface'],
    backendAuthority: ['PERSON_IDENTITY_SELECT', 'PERSON_REFERENCE_SELECT', 'projectPersonIdentity', 'projectPersonReference'],
    rule: 'A context-specific projection is legitimate; independently REINVENTING one is not. The test is composition, not narrowness.',
    limits: [
      'Backend classification uses a +/-12 line window to decide whether a select composes the canonical shape. A select spanning a wider range could be misclassified; every row carries its file and line so any verdict is checkable.',
      'CircleAvatar is classified person-bearing by nearby image/name signals. A decorative CircleAvatar sitting next to unrelated name text would be over-reported.',
      'This audit reads SOURCE. It proves nothing about what renders, and no rendered-image evidence is claimed — that half is CORS-blocked and stays in W2.',
    ],
  },
  totals: {
    rows: rows.length,
    byVerdict,
    nonConformant: tally((r) => r.verdict === 'NON_CONFORMANT'),
    adhocMapExtractionInSurface: tally((r) => r.verdict === 'ADHOC_MAP_EXTRACTION_IN_SURFACE'),
    typedDeserializationBoundary: tally((r) => r.verdict === 'TYPED_DESERIALIZATION_BOUNDARY'),
    conformant: tally((r) => r.verdict === 'CONFORMANT'),
    frontend: tally((r) => r.repo === 'aura_final'),
    backend: tally((r) => r.repo === 'aura-backend'),
  },
  sixPersonShapedExtractionSites: {
    obligation: 'CO-RC-C2-010',
    note: 'The six sites were named with future owners. This audit locates each in the current tree and reports what it found; it changes none of them and reassigns no owner.',
    sites: six,
  },
  consumers: rows.sort((a, b) => (a.repo + a.path).localeCompare(b.repo + b.path) || a.line - b.line),
}
writeFileSync(OUT, JSON.stringify(out, null, 1))
console.log('rows:', rows.length)
console.log('byVerdict:', JSON.stringify(byVerdict, null, 0))
console.log('six sites located:', six.filter((s) => s.reconciliation === 'LOCATED').length, '/ 6')
console.log('OK ->', OUT)
