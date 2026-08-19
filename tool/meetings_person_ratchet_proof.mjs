#!/usr/bin/env node
// FD-13 SEEDED PROOF — THE TYPED-PERSON RATCHET OVER THE PROTECTED MEETINGS
// MODELS.
//
// Founder requirement P: after the Meetings convergence the ratchet must still
// distinguish. It must FAIL when a protected Meetings model goes back to
// deciding person identity for itself, and it must NOT fail merely because the
// Meetings domain legitimately contains external guests, meeting roles, an
// actor union, or institution identity.
//
// A ratchet frozen at zero proves nothing on its own — zero is also what a
// blind detector reports. So this seeds the EXACT defect the founder ruling
// named, in the EXACT file it was found in, and asserts the gate fails.
//
//   TRUE POSITIVE   an AURA_USER person named by a private 'Guest' fallback
//   TRUE POSITIVE   a private person alias chain in a Meetings model
//   TRUE POSITIVE   raw person envelope parsing in a Meetings model
//   TRUE NEGATIVE   the tree as it now stands — which still contains the
//                   external GUEST fallback, meeting roles, the feed actor
//                   union and separate institution identity — is GREEN
//
// Non-mutating: every seed is written and reverted inside one step, and the
// harness refuses to exit without the working tree back as it found it.
import { readFileSync, writeFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(HERE, '..')
const GATE = resolve(HERE, 'identity_conformance_gate.mjs')

const IDENTITY = resolve(ROOT, 'lib/features/meetings/domain/meeting_identity.dart')
const MEETING = resolve(ROOT, 'lib/features/meetings/domain/meeting.dart')
const ENTRY = resolve(ROOT, 'lib/features/meetings/domain/meeting_entry_resolution.dart')

/** Run the gate. Returns true when it PASSES (exit 0). */
function gatePasses() {
  try {
    execFileSync(process.execPath, [GATE], { cwd: ROOT, stdio: 'pipe' })
    return true
  } catch {
    return false
  }
}

let failures = 0
const check = (label, actual, expected) => {
  const ok = actual === expected
  if (!ok) failures++
  console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}`)
  if (!ok) console.log(`        expected ${expected}, got ${actual}`)
}

// ── TRUE NEGATIVE, established first so a later PASS means something ──
console.log('\n── NEGATIVE: the Meetings domain as it stands is not debt ──')
check(
  'external GUEST fallback, meeting roles, actor union and institution ' +
    'identity all present — gate is GREEN',
  gatePasses(),
  true,
)

// ── TRUE POSITIVES: seed the real defect, one at a time ──
console.log('\n── POSITIVES: a protected Meetings model deciding person semantics ──')

const SEEDS = [
  {
    id: 'the founder-named defect: an AURA_USER named "Guest"',
    file: IDENTITY,
    find: `        identityType: 'AURA_USER',
        person: AuraPersonIdentity.fromJson(j),`,
    replace: `        identityType: 'AURA_USER',
        displayNameSeed: _requiredString(j['displayName'], fallback: 'Guest'),`,
  },
  {
    id: 'a private person alias chain in MeetingHost',
    file: MEETING,
    find: `  factory MeetingHost.fromJson(Map<String, dynamic> j) => MeetingHost(
    person: AuraPersonIdentity.fromJson(j),`,
    replace: `  factory MeetingHost.fromJson(Map<String, dynamic> j) => MeetingHost(
    seedName: (j['displayName'] ?? j['name'] ?? j['handle']) as String?,`,
  },
  {
    id: 'raw person envelope parsing in the entry resolver',
    file: ENTRY,
    find: `      identityPerson: isMember ? AuraPersonIdentity.fromJson(identity) : null,`,
    replace: `      identityPerson: null,
      seedName: (identity['user'] as Map?)?['displayName'] as String?,`,
  },
]

for (const seed of SEEDS) {
  const original = readFileSync(seed.file, 'utf8')
  if (!original.includes(seed.find)) {
    failures++
    console.log(`FAIL  ${seed.id}\n        seed anchor no longer present in ${seed.file}`)
    continue
  }
  try {
    writeFileSync(seed.file, original.replace(seed.find, seed.replace))
    check(`${seed.id} — gate FAILS`, gatePasses(), false)
  } finally {
    writeFileSync(seed.file, original)
  }
}

// ── RESTORATION: the tree must be exactly as we found it ──
console.log('\n── RESTORATION ──')
check('the gate is GREEN again after every seed is reverted', gatePasses(), true)

const dirty = execFileSync('git', ['status', '--porcelain', '--', 'lib/features/meetings/domain'], {
  cwd: ROOT,
  encoding: 'utf8',
})
  .split('\n')
  .filter((l) => l.trim())
// These three files carry the CONVERGENCE change itself while it is uncommitted,
// so their being modified is expected; what must not happen is a seed surviving.
const seedLeaked = [IDENTITY, MEETING, ENTRY].some((f) =>
  /displayNameSeed|seedName/.test(readFileSync(f, 'utf8')),
)
check('no seed text survives in any protected Meetings model', seedLeaked, false)
console.log(`        (working tree in that directory: ${dirty.length} modified file(s))`)

console.log(
  `\nMEETINGS TYPED-PERSON RATCHET PROOF: ${failures === 0 ? 'PASS (both directions)' : `FAIL (${failures})`}`,
)
process.exit(failures === 0 ? 0 : 1)
