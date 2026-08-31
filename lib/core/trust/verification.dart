/// C2 — VERIFICATION DOMAIN AUTHORITY (raw truth, no presentation).
///
/// The single frontend interpretation of the backend's layered Person
/// Verification Authority. Consumers never parse `verification.classes`
/// wire payloads themselves, and they never collapse the layered taxonomy
/// into a boolean — holding INSTITUTION_AFFILIATION says nothing about
/// IDENTITY, and a flattened "verified person" would claim more than any
/// single class supports.
///
/// WHAT THIS IS NOT:
///  - not a trust score, ranking or endorsement;
///  - not authorization — official institutional speech comes from
///    AUTHORITY (C1 capability projection), never from verification;
///  - not a portable credential — ROLE_OR_CREDENTIAL is an internal
///    governed attestation, not a W3C VC/DID/portable identity proof.
///
/// REVOKED/EXPIRED BY CONSTRUCTION: the public wire carries only the
/// currently-active class set (the backend authority removes a class on
/// revocation/expiry), so a stale positive signal cannot be represented
/// here at all. Richer revoked/expired history is an admin/governance
/// concern served by the admin verification endpoints.
library;

/// The frozen layered taxonomy (backend `PersonVerificationClass`,
/// taxonomy frozen 2026-08-15). Classes are INDEPENDENT — a person may
/// hold zero, one or several.
enum PersonVerificationClass {
  /// The person is who they claim to be.
  identity('IDENTITY'),

  /// A verified relationship/affiliation between the person and an
  /// institution.
  institutionAffiliation('INSTITUTION_AFFILIATION'),

  /// A governed claimed role, office, professional standing or credential.
  /// An internal attestation — never presented as portable.
  roleOrCredential('ROLE_OR_CREDENTIAL');

  const PersonVerificationClass(this.wireName);

  final String wireName;

  /// What this class is CALLED to a person reading it.
  ///
  /// `wireName` is the stored taxonomy word and belongs on the wire. The admin
  /// verification history was printing it straight onto the screen —
  /// `ROLE_OR_CREDENTIAL` beside a sentence written by an operator — which is
  /// the console speaking the schema at somebody trying to read a decision.
  ///
  /// Deliberately NOT derived by lowercasing the wire name: "Institution
  /// affiliation" and "Role or credential" are the taxonomy's own words for
  /// itself, and a mechanical transformation would drift the moment the
  /// taxonomy gains a class whose name does not survive it.
  String get label => switch (this) {
        PersonVerificationClass.identity => 'Identity',
        PersonVerificationClass.institutionAffiliation =>
          'Institution affiliation',
        PersonVerificationClass.roleOrCredential => 'Role or credential',
      };

  static PersonVerificationClass? tryParse(dynamic value) {
    final name = (value ?? '').toString().trim().toUpperCase();
    for (final c in PersonVerificationClass.values) {
      if (c.wireName == name) return c;
    }
    // Unknown classes are DROPPED, never guessed at: presenting an
    // unrecognized class with invented wording would be a fabricated
    // trust claim. A newer backend taxonomy entry simply stays quiet on
    // an older client.
    return null;
  }
}

/// The set of classes a person is CURRENTLY verified for. A set, never a
/// boolean.
class PersonVerification {
  const PersonVerification(this.classes);

  const PersonVerification.none() : classes = const [];

  final List<PersonVerificationClass> classes;

  bool get hasAny => classes.isNotEmpty;

  bool has(PersonVerificationClass c) => classes.contains(c);

  /// Parses the canonical wire shape `{"classes": ["IDENTITY", ...]}` as
  /// emitted by both the person profile endpoints and every embedded
  /// person identity (person-identity.ts). Anything malformed yields the
  /// empty set — absence of verification, never an error state.
  factory PersonVerification.fromJson(dynamic json) {
    if (json is! Map) return const PersonVerification.none();
    final raw = json['classes'];
    if (raw is! List) return const PersonVerification.none();
    final parsed = <PersonVerificationClass>[];
    for (final entry in raw) {
      final c = PersonVerificationClass.tryParse(entry);
      if (c != null && !parsed.contains(c)) parsed.add(c);
    }
    return PersonVerification(List.unmodifiable(parsed));
  }
}
