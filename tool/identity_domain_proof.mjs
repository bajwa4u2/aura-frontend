#!/usr/bin/env node
// DOMAIN-AWARE PERSON-IDENTITY DETECTOR — SEEDED ENFORCEMENT PROOF (FD-13).
//
// A detector that has never been shown to fail is an aspiration, and a
// detector that has only been shown to fail is a blunt instrument. This
// proves BOTH directions, because founder ruling 1 asks for accuracy, not
// narrowness:
//
//   TRUE POSITIVE  — a genuine private person parser must be caught.
//   FALSE POSITIVE — an institution or external-platform field wearing the
//                    same generic name must NOT become person debt.
//
// It also proves ruling 2's distinction: a typed domain model that DELEGATES
// its person portion is conformant, while one that decides person semantics
// itself is not — regardless of how legitimate the surrounding type is.
import {
  classifyIdentityDomain,
  enclosingTypeName,
  personAliasListKeys,
  statementSubjectName,
  statementTargetName,
  typedPersonVerdict,
} from './identity_consumer_audit.mjs'

let failures = 0
const check = (label, actual, expected) => {
  const ok = actual === expected
  if (!ok) failures++
  console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}\n        expected ${expected}, got ${actual}`)
}

console.log('\n── TRUE POSITIVES: person semantics must be detected ──')

check(
  'a person read off a plain map',
  classifyIdentityDomain("final name = (user['displayName'] ?? '').toString();", 'final user = m;'),
  'PERSON',
)
check(
  'a nested person envelope',
  classifyIdentityDomain("final h = (author['handle'] ?? '').toString();", 'final author = j;'),
  'PERSON',
)
check(
  'an avatar alias chain on a person',
  classifyIdentityDomain("m['avatarUrl'] ?? m['avatar'] ?? m['imageUrl'],", 'final m = authorMap;'),
  'PERSON',
)
check(
  'a member payload',
  classifyIdentityDomain("displayName: _str(member['displayName']),", 'final member = row;'),
  'PERSON',
)

console.log('\n── FALSE POSITIVES: same field names, different domain ──')

check(
  'an institution display name',
  classifyIdentityDomain("final name = (inst?['name'] ?? inst?['displayName'] ?? '');", 'final inst = institutionMap;'),
  'INSTITUTION',
)
check(
  'an institution logo through an avatar-shaped field',
  classifyIdentityDomain("? inst['avatarUrl'].toString().trim()", 'final inst = institution;'),
  'INSTITUTION',
)
check(
  'an institution actor',
  classifyIdentityDomain("actorInstitution['displayName']?.toString(),", 'final actorInstitution = x;'),
  'INSTITUTION',
)
check(
  'an institution admin handle inside a realtime model',
  classifyIdentityDomain("_readString(institutionAdmin['handle']) ??", 'final institutionAdmin = m;'),
  'INSTITUTION',
)
check(
  'a connected TikTok account label',
  classifyIdentityDomain(
    "data['displayName']?.toString(),",
    "_tiktokConnected = data['connected'] == true;\n_tiktokAccountLabel = _firstNonEmpty([\n  data['displayName'],\n  data['username'],\n  data['accountLabel'],\n]);",
  ),
  'EXTERNAL_PLATFORM',
)

check(
  'a person who stands in an institutional relationship is still a person',
  classifyIdentityDomain("displayName: _s(institutionMember['displayName']),", 'final institutionMember = row;'),
  'PERSON',
)

console.log('\n── DESTINATION: a continuation line is judged by its statement ──')

// The tail of a multi-line institution resolution reads a map that is not
// itself named for an institution. Read alone it looks like person debt; read
// as the sentence it belongs to, it is an institution's handle.
const CONTINUATION = [
  "    final institutionHandle = _readString(normalized['institutionHandle']) ??",
  "        _readString(_asMap(firstMembership['institution'])['handle']);",
]
check(
  'the statement target of a continuation line',
  statementTargetName(CONTINUATION, 1),
  'institutionHandle',
)
check(
  'an institution handle resolved on a continuation line',
  classifyIdentityDomain(CONTINUATION[1], CONTINUATION.join('\n'), statementTargetName(CONTINUATION, 1)),
  'INSTITUTION',
)
check(
  'a person name resolved on a continuation line is untouched by that rule',
  classifyIdentityDomain(
    "        _readString(user['displayName']);",
    "    final displayName = _readString(normalized['displayName']) ??\n_readString(user['displayName']);",
    'displayName',
  ),
  'PERSON',
)

// A key-path helper puts the field name on a line of its own. The subject of
// the statement is the only thing that says whose field it is.
const INSTITUTION_KEYPATH = [
  "      final name = _extractFirstString(inst, const [",
  "        ['displayName'],",
  "      ]).trim();",
]
const PERSON_KEYPATH = [
  "      final name = _extractFirstString(actor, const [",
  "        ['displayName'],",
  "      ]).trim();",
]
check(
  'a key-path field read whose subject is an institution',
  classifyIdentityDomain(
    INSTITUTION_KEYPATH[1],
    INSTITUTION_KEYPATH.join('\n'),
    statementTargetName(INSTITUTION_KEYPATH, 1),
    statementSubjectName(INSTITUTION_KEYPATH, 1),
  ),
  'INSTITUTION',
)
check(
  'the identical line whose subject is a person',
  classifyIdentityDomain(
    PERSON_KEYPATH[1],
    PERSON_KEYPATH.join('\n'),
    statementTargetName(PERSON_KEYPATH, 1),
    statementSubjectName(PERSON_KEYPATH, 1),
  ),
  'PERSON',
)

console.log('\n── TYPED BOUNDARY: containing a person is not the defect ──')

check(
  'a typed model that DELEGATES its person portion',
  typedPersonVerdict(`
    factory BlockRelationship.fromJson(Map<String, dynamic> j) => BlockRelationship(
          person: AuraPersonIdentity.fromJson(j['blocked']),
          blockedAt: DateTime.parse(j['blockedAt']),
        );`),
  'CANONICAL_PERSON_DESERIALIZATION',
)
check(
  'a typed model that decides person semantics itself',
  typedPersonVerdict(`
    factory BlockRelationship.fromJson(Map<String, dynamic> j) => BlockRelationship(
          handle: (j['handle'] ?? '') as String,
          displayName: (j['displayName'] ?? j['name'] ?? '') as String,
          blockedAt: DateTime.parse(j['blockedAt']),
        );`),
  'NON_CANONICAL_PERSON_DESERIALIZATION',
)

// ── ALIAS LISTS: the same defect, written as a list ──
// Added 2026-08-19 during the F116 promotion reconciliation. The single-key
// matcher could not see `pick(map, const ['displayName', 'name'])`, which is
// the STRONGER form of the defect - a list IS a private alias order. Real
// person debt was removed from the app shell and the member directory and the
// metric moved by ZERO, which is how a gate becomes decoration.
console.log('')
console.log('-- ALIAS LISTS: a private alias ORDER must be visible --')

check(
  'two person keys quoted together are an alias order',
  (personAliasListKeys(["final n = pick(m, const ['displayName', 'name']);"], 0) ?? []).join(','),
  'displayName,name',
)
check(
  'a single-key list is a lookup, not an alias order',
  personAliasListKeys(["final n = pick(m, const ['displayName']);"], 0),
  null,
)
check(
  'a non-person list is not person debt',
  personAliasListKeys(["final s = pick(m, const ['status', 'state']);"], 0),
  null,
)
check(
  'a list that OPENS on a later line is not charged to this one',
  personAliasListKeys(
    ["title: s(['title']),", 'body: s([]),', "name: opt(i, ['name', 'displayName']),"],
    0,
  ),
  null,
)
check(
  'a same-line receiver decides the domain, even inside a multi-line call',
  statementSubjectName(
    ['return ExploreFeedItem(', 'id: s([]),', "institutionName: opt(inst, ['name', 'displayName']),"],
    2,
  ),
  'inst',
)

console.log('')
console.log('-- ENCLOSING TYPE: the last signal, and the weakest --')
check(
  'a model that names itself an institution',
  enclosingTypeName(['class Institution {', "    name: readString(['name', 'displayName']),"], 1),
  'Institution',
)
check(
  "Dart's privacy underscore is not part of the name",
  enclosingTypeName(['class _InstitutionProfileState {', "  final n = _str(['name', 'displayName']);"], 1),
  'InstitutionProfileState',
)
check(
  'an institution class reading its own name is not person debt',
  classifyIdentityDomain("name: readString(['name', 'displayName']),", '', 'name', '', 'Institution'),
  'INSTITUTION',
)
check(
  'a PERSON inside an institution-named class is still a person',
  classifyIdentityDomain("final n = pick(member, const ['displayName', 'name']);", '', 'n', 'member', 'InstitutionMemberTile'),
  'PERSON',
)
check(
  'a class name never outranks a named receiver',
  classifyIdentityDomain("final n = pick(user, const ['displayName', 'name']);", '', 'n', 'user', 'InstitutionProfileState'),
  'PERSON',
)

console.log(
  failures === 0
    ? '\nDOMAIN-AWARE DETECTOR PROOF: PASS (both directions)\n'
    : `\nDOMAIN-AWARE DETECTOR PROOF: FAIL — ${failures} case(s)\n`,
)
process.exit(failures === 0 ? 0 : 1)
