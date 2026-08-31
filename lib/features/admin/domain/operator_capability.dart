/// OPERATOR CAPABILITY — the client's typed view of admin authority.
///
/// THE SERVER IS THE AUTHORITY. Nothing here decides what an operator may do;
/// `GET /v1/admin/me` already decided, and every endpoint enforces it again.
/// This exists so the interface can tell the truth about that decision instead
/// of showing every operator every door.
///
/// WHY IT DID NOT EXIST
/// --------------------
/// The client already fetched the full authority — role, permissions, grants —
/// and threw it away: `admin_access_provider` reduced all of it to one boolean.
/// The parsing was broken too, and silently: `AdminAccess.fromJson` read
/// `role` and `permissions`, while the server returns `roles` and
/// `effectivePermissions`. So the list was ALWAYS empty, which is very likely
/// why nobody ever built gating on it — the data looked like it wasn't there.
///
/// The consequence was live: a MODERATOR holds 4 permissions and an ANALYST
/// holds 3, and both saw the same fourteen navigation entries as an OWNER
/// holding all 25.
library;

/// The 25 permissions defined by `AdminPermission` in the backend schema.
///
/// Two separations are deliberate and carry recorded governance rationale.
/// They are mirrored here exactly and must never be collapsed for the
/// convenience of a menu:
///
///   * [identityVerificationRead]/[identityVerificationWrite] are NOT
///     [verificationRead]/[verificationWrite]. Identity proof and
///     institutional legitimacy are different proofs.
///   * [productFeedbackRead]/[productFeedbackWrite] are NOT [supportRead]/
///     [supportWrite]. Support can email a person; feedback cannot.
enum OperatorCapability {
  usersRead('USERS_READ'),
  usersWrite('USERS_WRITE'),
  moderationRead('MODERATION_READ'),
  moderationWrite('MODERATION_WRITE'),
  verificationRead('VERIFICATION_READ'),
  verificationWrite('VERIFICATION_WRITE'),
  identityVerificationRead('IDENTITY_VERIFICATION_READ'),
  identityVerificationWrite('IDENTITY_VERIFICATION_WRITE'),
  institutionsRead('INSTITUTIONS_READ'),
  institutionsWrite('INSTITUTIONS_WRITE'),
  announcementsRead('ANNOUNCEMENTS_READ'),
  announcementsWrite('ANNOUNCEMENTS_WRITE'),
  communicationsRead('COMMUNICATIONS_READ'),
  communicationsWrite('COMMUNICATIONS_WRITE'),
  communicationsApprove('COMMUNICATIONS_APPROVE'),
  communicationsSend('COMMUNICATIONS_SEND'),
  auditRead('AUDIT_READ'),
  analyticsRead('ANALYTICS_READ'),
  settingsRead('SETTINGS_READ'),
  settingsWrite('SETTINGS_WRITE'),
  systemHealthRead('SYSTEM_HEALTH_READ'),
  supportRead('SUPPORT_READ'),
  supportWrite('SUPPORT_WRITE'),
  productFeedbackRead('PRODUCT_FEEDBACK_READ'),
  productFeedbackWrite('PRODUCT_FEEDBACK_WRITE'),
  discoveryRead('DISCOVERY_READ'),
  discoveryEvidenceRead('DISCOVERY_EVIDENCE_READ');

  const OperatorCapability(this.wire);

  /// The exact `AdminPermission` value. Never derived from the enum name —
  /// a rename here must not silently change what is asked of the server.
  final String wire;

  static final Map<String, OperatorCapability> _byWire = {
    for (final c in OperatorCapability.values) c.wire: c,
  };

  /// Unknown values return null rather than throwing: a server one version
  /// ahead must not break an operator's whole console.
  static OperatorCapability? fromWire(String? value) =>
      value == null ? null : _byWire[value.trim().toUpperCase()];
}

/// Admin roles, as defined by `AdminRole`.
enum OperatorRole {
  owner('OWNER'),
  admin('ADMIN'),
  moderator('MODERATOR'),
  analyst('ANALYST'),
  support('SUPPORT');

  const OperatorRole(this.wire);

  final String wire;

  static OperatorRole? fromWire(String? value) {
    if (value == null) return null;
    final v = value.trim().toUpperCase();
    for (final r in OperatorRole.values) {
      if (r.wire == v) return r;
    }
    return null;
  }

  String get label => switch (this) {
        OperatorRole.owner => 'Owner',
        OperatorRole.admin => 'Administrator',
        OperatorRole.moderator => 'Moderator',
        OperatorRole.analyst => 'Analyst',
        OperatorRole.support => 'Support',
      };
}

/// What this operator actually holds, as the server reported it.
class OperatorAuthority {
  const OperatorAuthority({
    required this.userId,
    required this.roles,
    required this.capabilities,
    required this.unknownCapabilities,
    this.primaryRole,
    this.expiresAt,
  });

  const OperatorAuthority.none()
      : userId = '',
        roles = const {},
        capabilities = const {},
        unknownCapabilities = const {},
        primaryRole = null,
        expiresAt = null;

  final String userId;
  final Set<OperatorRole> roles;

  /// The server's `effectivePermissions`, which already accounts for the trap
  /// that an explicit grant permission list OVERRIDES role defaults entirely.
  /// The client never recomputes this from roles — doing so would reintroduce
  /// exactly that bug on the other side of the wire.
  final Set<OperatorCapability> capabilities;

  /// Permission strings this build does not recognise. Kept rather than
  /// discarded so a newer server's scopes are visible as a fact instead of
  /// looking like the operator holds nothing.
  final Set<String> unknownCapabilities;

  final OperatorRole? primaryRole;
  final DateTime? expiresAt;

  /// Operator-ness is a CAPABILITY fact, never a role one. This used to read
  /// `capabilities.isNotEmpty || isOwner`, which answered a capability
  /// question with a role boolean — the exact drift the C1 ratchet exists to
  /// stop, and it would have admitted an OWNER whose grant had been narrowed
  /// to nothing.
  bool get isOperator => capabilities.isNotEmpty;

  /// Whether this operator holds the OWNER role. For DISPLAY and governance
  /// acts only — never to answer "may they do X".
  bool get holdsOwnerRole => roles.contains(OperatorRole.owner);

  bool can(OperatorCapability capability) =>
      capabilities.contains(capability);

  bool canAny(Iterable<OperatorCapability> any) =>
      any.any(capabilities.contains);

  bool canAll(Iterable<OperatorCapability> all) =>
      all.every(capabilities.contains);

  /// True when the grant carries an expiry that has passed. The server is
  /// still the authority; this exists so the interface can say so plainly
  /// rather than presenting actions that will be refused.
  bool expiredAt(DateTime now) =>
      expiresAt != null && !expiresAt!.isAfter(now);

  /// Parses `GET /v1/admin/me`.
  ///
  /// Field names are the SERVER'S, not the ones the old client model guessed:
  /// `roles` (plural) and `effectivePermissions`.
  factory OperatorAuthority.fromMe(Map<String, dynamic> json) {
    final known = <OperatorCapability>{};
    final unknown = <String>{};
    for (final raw in _stringList(json['effectivePermissions'])) {
      final parsed = OperatorCapability.fromWire(raw);
      if (parsed != null) {
        known.add(parsed);
      } else {
        unknown.add(raw);
      }
    }

    final roles = <OperatorRole>{};
    for (final raw in _stringList(json['roles'])) {
      final parsed = OperatorRole.fromWire(raw);
      if (parsed != null) roles.add(parsed);
    }

    final primary = json['primaryGrant'];
    OperatorRole? primaryRole;
    DateTime? expires;
    if (primary is Map) {
      primaryRole = OperatorRole.fromWire(primary['role']?.toString());
      final rawExpiry = primary['expiresAt'];
      if (rawExpiry is String && rawExpiry.trim().isNotEmpty) {
        expires = DateTime.tryParse(rawExpiry);
      }
    }

    return OperatorAuthority(
      userId: json['userId']?.toString() ?? '',
      roles: roles,
      capabilities: known,
      unknownCapabilities: unknown,
      primaryRole: primaryRole ?? (roles.isNotEmpty ? roles.first : null),
      expiresAt: expires,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
