/// Domain model for institution-scoped activity events.
///
/// Mirrors the backend contract:
///   InstitutionActivityEvent = {
///     id, institutionId, actorUserId?, kind, targetType?, targetId?, metadata?,
///     visibility: 'PUBLIC' | 'MEMBER' | 'ADMIN',
///     createdAt
///   }
library;

enum InstitutionActivityVisibility { publicAll, member, admin }

extension InstitutionActivityVisibilityX on InstitutionActivityVisibility {
  String get wire {
    switch (this) {
      case InstitutionActivityVisibility.publicAll:
        return 'PUBLIC';
      case InstitutionActivityVisibility.member:
        return 'MEMBER';
      case InstitutionActivityVisibility.admin:
        return 'ADMIN';
    }
  }

  static InstitutionActivityVisibility fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    switch (s) {
      case 'ADMIN':
        return InstitutionActivityVisibility.admin;
      case 'MEMBER':
        return InstitutionActivityVisibility.member;
      case 'PUBLIC':
      default:
        return InstitutionActivityVisibility.publicAll;
    }
  }
}

class InstitutionActivityEvent {
  const InstitutionActivityEvent({
    required this.id,
    required this.institutionId,
    required this.actorUserId,
    required this.kind,
    required this.targetType,
    required this.targetId,
    required this.metadata,
    required this.visibility,
    required this.createdAt,
    this.actor,
    this.targetRoute,
  });

  final String id;
  final String institutionId;
  final String? actorUserId;
  final String kind;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic>? metadata;
  final InstitutionActivityVisibility visibility;
  final DateTime? createdAt;

  /// Optional embedded actor summary (display name, handle, avatarUrl) when
  /// the API includes it.
  final Map<String, dynamic>? actor;

  /// Canonical navigation route when the activity refers to a navigable
  /// entity (post, announcement, etc.). Null for non-actionable rows like
  /// "INSTITUTION_VERIFIED". Surfaces inside a different shell may rewrite
  /// via `FeedRouting.adaptTargetRoute`.
  final String? targetRoute;

  bool get isActionable => targetRoute != null && targetRoute!.isNotEmpty;

  factory InstitutionActivityEvent.fromJson(Map<String, dynamic> json) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = json[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? opt(List<String> keys) {
      for (final k in keys) {
        final v = json[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final str = raw.toString().trim();
      if (str.isEmpty) return null;
      return DateTime.tryParse(str);
    }

    Map<String, dynamic>? readMap(dynamic raw) {
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    }

    return InstitutionActivityEvent(
      id: s(['id']),
      institutionId: s(['institutionId']),
      actorUserId: opt(['actorUserId', 'actorId']),
      kind: s(['kind', 'type']),
      targetType: opt(['targetType']),
      targetId: opt(['targetId']),
      metadata: readMap(json['metadata']),
      visibility: InstitutionActivityVisibilityX.fromWire(json['visibility']),
      createdAt: readDate(json['createdAt']),
      actor: readMap(json['actor']),
      targetRoute: opt(['targetRoute']),
    );
  }

  /// Heuristic categorization for the filter chip row.
  /// Returns one of: 'members', 'posts', 'admin', 'other'.
  String get category {
    final k = kind.toUpperCase();
    if (k.startsWith('MEMBER_') ||
        k.startsWith('ROLE_') ||
        k.startsWith('INVITE_') ||
        k.startsWith('JOIN_REQUEST_')) {
      return 'members';
    }
    if (k.startsWith('POST_') || k.startsWith('ANNOUNCEMENT_')) {
      return 'posts';
    }
    if (visibility == InstitutionActivityVisibility.admin ||
        k.startsWith('ADMIN_') ||
        k.startsWith('SECURITY_') ||
        k.startsWith('VERIFICATION_') ||
        k == 'INSTITUTION_VERIFIED' ||
        k == 'INSTITUTION_SUSPENDED') {
      return 'admin';
    }
    return 'other';
  }
}
