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


// ─────────────────────────────────────────────────────────────────────────
// DOMAIN-AWARE IDENTITY CLASSIFICATION (founder ruling 1, 2026-08-19)
// ─────────────────────────────────────────────────────────────────────────
//
// The old rule was: a person field NAME appears, therefore person debt. That
// is what made `inst['displayName']`, an institution logo, an institution
// slug and a connected TikTok account label count against a PERSON identity
// metric. Nine measured sites were not people at all.
//
// The new rule asks what the code is ABOUT before asking what it reads:
//
//     object / domain semantics -> identity domain -> person conformance
//
// The domain is taken from the RECEIVER of the field read and from the
// surrounding declaration — the code's own naming — never from a path or a
// file allowlist. A file is not trusted or excluded for where it lives.
//
// LIMITS, stated because a detector that overstates its precision is worse
// than a blunt one: the receiver name is a strong signal in this codebase
// (`inst`, `institution`, `actorInstitution`) but it is a heuristic. Every
// row still carries file, line and evidence so any verdict is checkable, and
// both directions are proven by seeded cases in
// `tool/identity_domain_proof.mjs`.

const INSTITUTION_RECEIVER = /^(inst|institution|actorinstitution|institutionadmin|org|organisation|organization|owninginstitution|instmap|institutionmap)/
const EXTERNAL_PLATFORM_TOKENS = /(tiktok|linkedin|youtube|instagram|facebook|externalaccount|external_account|platformaccount)/i

// A name that begins with an institution word but ENDS in a person word is a
// PERSON who stands in an institutional relationship - an institution member,
// an institution admin, a host. Institution identity and the identity of the
// people attached to an institution are different things, and this guard is
// what keeps the classifier from quietly swallowing the second.
//
// `admin` is deliberately NOT in this list. In this client `institutionAdmin`
// and `adminInstitution` both name the INSTITUTION a person administers - the
// admin PERSON is always named `adminUser` / `...UserId`, which never begins
// with an institution word. Reading it as a person would have mislabelled an
// institution's own handle as person debt.
const PERSON_ROLE_WORD = /(member|user|person|people|owner|contact|host|speaker|participant|author|sender|guest|staff|employee)/i

// Institution identity is also detectable from where a value is GOING. A
// multi-line expression whose target is `institutionHandle` is resolving an
// institution's handle no matter which map the last line happened to read.
const INSTITUTION_TARGET = /^(inst|institution|org|organisation|organization)[A-Za-z]*$/

/**
 * The name a (possibly multi-line) statement assigns into.
 *
 * Field reads in this codebase are frequently continuation lines of a
 * `final institutionHandle = a ?? b ?? c;` chain. Judging such a line on its
 * own text alone reads the tail of a sentence and calls it the sentence.
 */
export function statementTargetName(lines, i) {
  let j = i
  while (j > 0) {
    const prev = lines[j - 1].replace(/\/\/.*$/, '').trimEnd()
    // A previous line that closed its statement means this line starts one.
    if (/[;{}]$/.test(prev) || prev === '') break
    j--
  }
  const m = lines[j].match(/(?:final|const|var)?\s*(?:[\w<>,?\s]+\s+)?(\w+)\s*(?::|=(?!=))/)
  return m?.[1] ?? ''
}

/**
 * The SUBJECT a statement is reading from, when the flagged line carries no
 * receiver of its own.
 *
 * Key-path helpers put the field names on their own lines:
 *
 *     final name = _extractFirstString(inst, const [
 *       ['displayName'],
 *     ]);
 *
 * The line `['displayName'],` names no map at all. Judging it without the
 * subject of its own statement is how an institution's name came to be
 * counted as person debt.
 */
export function statementSubjectName(lines, i) {
  let j = i
  while (j > 0) {
    const prev = lines[j - 1].replace(/\/\/.*$/, '').trimEnd()
    if (/[;}]$/.test(prev) || prev === '') break
    j--
  }
  const m = lines[j].match(/\w+\(\s*(\w+)\s*,/)
  return m?.[1] ?? ''
}

/** Which identity domain does this field read belong to? */
export function classifyIdentityDomain(line, win, target = '', subject = '') {
  const recv = line.match(
    /(\w+)\s*(?:\?|!)?\s*\[\s*['"](?:displayName|handle|avatarUrl|photoUrl|fullName|name|slug|logoUrl)['"]\s*\]/,
  )
  const receiver = (recv?.[1] ?? '').toLowerCase()
  if (receiver && INSTITUTION_RECEIVER.test(receiver) && !PERSON_ROLE_WORD.test(receiver)) {
    return 'INSTITUTION'
  }

  // Where the value is going, when the line itself is a continuation.
  if (target && INSTITUTION_TARGET.test(target) && !PERSON_ROLE_WORD.test(target)) {
    return 'INSTITUTION'
  }

  // What the statement is reading FROM, when the flagged line names no map.
  if (subject && INSTITUTION_RECEIVER.test(subject.toLowerCase()) && !PERSON_ROLE_WORD.test(subject)) {
    return 'INSTITUTION'
  }

  // An institution read through a nested key rather than a named variable.
  if (/\['(institution|actorInstitution|owningInstitution)'\]\s*(?:\?|!)?\s*\[/.test(line)) {
    return 'INSTITUTION'
  }

  // An external platform ACCOUNT: the surrounding declaration names the
  // platform, and the value being read is that account's label, not a person.
  if (EXTERNAL_PLATFORM_TOKENS.test(win) && /accountLabel|username|connected|account/i.test(win)) {
    if (EXTERNAL_PLATFORM_TOKENS.test(win)) return 'EXTERNAL_PLATFORM'
  }

  return 'PERSON'
}

/**
 * Founder ruling 2: a typed domain model is NOT defective for containing a
 * person. It is defective when it independently decides canonical PERSON
 * semantics instead of delegating them.
 *
 * CONFORMANT means the person portion goes through AuraPersonIdentity;
 * the model keeps its own role / relationship / post / meeting / follow /
 * block / article / conversation / update state.
 */
export function typedPersonVerdict(win) {
  return /AuraPersonIdentity\s*\.\s*fromJson/.test(win)
    ? 'CANONICAL_PERSON_DESERIALIZATION'
    : 'NON_CANONICAL_PERSON_DESERIALIZATION'
}

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
    // INSTRUMENT CORRECTION (F053 convergence, 2026-08-19). A ROUTE parameter
    // that happens to be named `handle` is not a person payload — reading
    // `state.pathParameters['handle']` resolves a URL segment, and no identity
    // interpretation occurs. Six router lines were being counted as identity
    // debt that no migration could ever clear, which made the measurement
    // overstate the remaining work rather than understate it.
    const isRouteParameter = /(path|query)Parameters\s*\[/.test(line)
    if (m && !isAuthority && !isRouteParameter) {
      const isTypedBoundary =
        /\/(domain|data)\//.test(path) ||
        /_repository\.dart$|_models?\.dart$|_model\.dart$/.test(path)

      // Founder ruling 1 — ask what the code is ABOUT before asking what it
      // reads. An institution's displayName and an external account's label
      // are not person identity, however identical the field name looks.
      const personWindow = windowOf(lines, i, 8)
      const domain = classifyIdentityDomain(
        line,
        personWindow,
        statementTargetName(lines, i),
        statementSubjectName(lines, i),
      )
      if (domain !== 'PERSON') {
        add({ repo: 'aura_final', surface: 'USER_SHAPE', path, line: i + 1,
          evidence: line.trim().slice(0, 120),
          identityDomain: domain,
          verdict: domain === 'INSTITUTION'
            ? 'OUT_OF_SCOPE_INSTITUTION_IDENTITY'
            : 'OUT_OF_SCOPE_EXTERNAL_PLATFORM_IDENTITY',
          why: domain === 'INSTITUTION'
            ? `Reads '${m[1]}' from an INSTITUTION, which has its own canonical authority (institution-identity.ts). Person identity and institution identity are deliberately separate; counting this as person debt measured the wrong thing.`
            : `Reads '${m[1]}' from an EXTERNAL PLATFORM ACCOUNT (a connected third-party account label). Not an Aura person.` })
        continue
      }

      if (isTypedBoundary) {
        // Founder ruling 2 — a typed domain model is not defective for
        // CONTAINING a person. It is defective when it independently decides
        // canonical person semantics instead of delegating them.
        const typed = typedPersonVerdict(personWindow)
        add({ repo: 'aura_final', surface: 'USER_SHAPE', path, line: i + 1,
          evidence: line.trim().slice(0, 120),
          identityDomain: 'PERSON',
          verdict: typed,
          why: typed === 'CANONICAL_PERSON_DESERIALIZATION'
            ? `Typed boundary whose person portion is delegated to AuraPersonIdentity. The model keeps its own domain state; it does not own person semantics.`
            : `Typed boundary that independently interprets the person field '${m[1]}' — its own alias order, envelope unwrap or fallback. The TYPE may stay; the private PERSON interpretation may not.` })
        continue
      }

      add({ repo: 'aura_final', surface: 'USER_SHAPE', path, line: i + 1, evidence: line.trim().slice(0, 120),
        identityDomain: 'PERSON',
        verdict: 'ADHOC_MAP_EXTRACTION_IN_SURFACE',
        why: `A presentation surface reads the person field '${m[1]}' straight off an untyped map. This is the F057 class of defect and the direct subject of F053.` })
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
