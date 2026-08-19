import '../../../core/identity/person_identity_model.dart';

/// WHO a meeting identity belongs to.
///
/// F053 / F116 — founder ruling 2026-08-19. This model spans three genuinely
/// different kinds of participant, and only ONE of them is an Aura person:
///
///   AURA_USER  → a person who holds an Aura identity
///   CONTACT    → a saved external contact
///   GUEST      → an external participant with no Aura identity at all
///
/// The defect this separation corrects: `fromUserJson` built an AURA_USER ref
/// and still defaulted the name to `'Guest'` when a display name was missing.
/// That named an identifiable Aura person by an EXTERNAL PARTICIPANT TYPE they
/// do not hold — person identity answered by a meeting role. An Aura user is
/// not a guest merely because their display identity is incomplete.
///
///   PERSON IDENTITY  ≠  MEETING ROLE / EXTERNAL PARTICIPANT TYPE
///
/// So the person branch now delegates to the canonical Aura person authority,
/// including its unknown-person fallback, and the external branch keeps the
/// meeting domain's own `'Guest'` — which is correct there and is deliberately
/// left alone. Everything else on this ref (participant type, member/contact
/// pointers, email, verification, institutional title) is meeting-domain state
/// and stays exactly where it was.
class MeetingIdentityRef {
  const MeetingIdentityRef({
    required this.identityType,
    required this.email,
    required this.verifiedEmail,
    this.person,
    this.externalName,
    this.memberId,
    this.contactId,
    this.title,
  });

  /// Meeting-domain participant type: AURA_USER | CONTACT | GUEST.
  final String identityType;

  /// The Aura person — present only when this ref names one.
  final AuraPersonIdentity? person;

  /// The name an EXTERNAL participant supplied. A contact or a guest is not an
  /// Aura person and is deliberately not forced into one.
  final String? externalName;

  /// Meeting-domain pointers and state.
  final String? memberId;
  final String? contactId;
  final String email;
  final String? title;
  final bool verifiedEmail;

  bool get isAuraUser => person != null;

  String? get auraUserId {
    final id = person?.userId ?? '';
    return id.isEmpty ? null : id;
  }

  /// What to call this participant.
  ///
  /// An Aura person is named by the canonical order — their name, then their
  /// handle, then the one neutral word the whole product shares. An external
  /// participant keeps the meeting domain's own fallback, because for them
  /// "Guest" is an accurate statement of what they are.
  String get displayName {
    final aura = person;
    if (aura != null) return aura.label;
    final external = (externalName ?? '').trim();
    return external.isEmpty ? 'Guest' : external;
  }

  String? get handle {
    final h = (person?.handle ?? '').trim();
    return h.isEmpty ? null : h;
  }

  /// Only an Aura person carries an identity image; the meeting domain does
  /// not synthesize one for external participants.
  String? get avatarUrl => person?.avatarUrl;

  factory MeetingIdentityRef.fromJson(Map<String, dynamic> j) {
    final identityType = _requiredString(j['identityType'], fallback: 'GUEST');
    final auraUserId = _optionalString(j['auraUserId']);
    final isAuraUser = identityType == 'AURA_USER' || auraUserId != null;
    return MeetingIdentityRef(
      identityType: identityType,
      person: isAuraUser
          ? AuraPersonIdentity.fromJson(<String, dynamic>{
              'userId': auraUserId,
              'displayName': j['displayName'],
              'handle': j['handle'],
              'avatarUrl': j['avatarUrl'],
            })
          : null,
      externalName: isAuraUser ? null : _optionalString(j['displayName']),
      memberId: _optionalString(j['memberId']),
      contactId: _optionalString(j['contactId']),
      email: _requiredString(j['email']),
      title: _optionalString(j['title']),
      verifiedEmail: j['verifiedEmail'] as bool? ?? false,
    );
  }

  /// The authenticated Aura identity, read straight from the account payload.
  /// Always a person — there is no guest branch here to fall into.
  factory MeetingIdentityRef.fromUserJson(Map<String, dynamic> j) =>
      MeetingIdentityRef(
        identityType: 'AURA_USER',
        person: AuraPersonIdentity.fromJson(j),
        memberId: _optionalString(j['memberId']),
        contactId: _optionalString(j['contactId']),
        email: _requiredString(j['email']),
        title: _optionalString(j['title']),
        verifiedEmail:
            j['emailVerifiedAt'] != null || j['emailVerified'] == true,
      );
}

String _requiredString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final t = value.trim();
    if (t.isNotEmpty) return t;
  }
  return fallback;
}

String? _optionalString(dynamic value) {
  if (value is String) {
    final t = value.trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}
