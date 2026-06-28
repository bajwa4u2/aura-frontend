class MeetingIdentityRef {
  final String? auraUserId;
  final String? memberId;
  final String? contactId;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String? title;
  final String? handle;
  final String identityType;
  final bool verifiedEmail;

  const MeetingIdentityRef({
    required this.auraUserId,
    required this.memberId,
    required this.contactId,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.title,
    required this.handle,
    required this.identityType,
    required this.verifiedEmail,
  });

  factory MeetingIdentityRef.fromJson(Map<String, dynamic> j) =>
      MeetingIdentityRef(
        auraUserId: _optionalString(j['auraUserId']),
        memberId: _optionalString(j['memberId']),
        contactId: _optionalString(j['contactId']),
        displayName: _requiredString(j['displayName'], fallback: 'Guest'),
        email: _requiredString(j['email']),
        avatarUrl: _optionalString(j['avatarUrl']),
        title: _optionalString(j['title']),
        handle: _optionalString(j['handle']),
        identityType: _requiredString(j['identityType'], fallback: 'GUEST'),
        verifiedEmail: j['verifiedEmail'] as bool? ?? false,
      );

  factory MeetingIdentityRef.fromUserJson(Map<String, dynamic> j) =>
      MeetingIdentityRef(
        auraUserId: _optionalString(j['id']),
        memberId: _optionalString(j['memberId']),
        contactId: _optionalString(j['contactId']),
        displayName: _requiredString(j['displayName'], fallback: 'Guest'),
        email: _requiredString(j['email']),
        avatarUrl: _optionalString(j['avatarUrl']),
        title: _optionalString(j['title']),
        handle: _optionalString(j['handle']),
        identityType: 'AURA_USER',
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
