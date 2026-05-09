import '../../core/interactions/actor_context.dart';

/// Typed notification row used by the Notifications screen.
///
/// This model is the canonical typed view over the raw notification map
/// returned by the backend (and cached as `Map<String, dynamic>` inside
/// `NotificationsController.state.items`). One canonical mapper avoids the
/// historical drift that produced two parallel parsers — see PR notes for
/// the consolidation rationale.
///
/// Tolerates:
///   * unknown `type` — preserved verbatim so the renderer can fall back to
///     a generic "$actor interacted with your content" tile.
///   * unknown / null `actorType` — defaults to USER.
///   * missing `actor` / `actorInstitution` — null; renderer uses initial
///     fallback letter.
///   * missing target ids — null; the row still renders, tap may no-op.
///   * unparseable `createdAt` — falls back to `DateTime.now()`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.type,
    required this.actorType,
    this.actorId,
    this.actorInstitutionId,
    this.actor,
    this.actorInstitution,
    this.postId,
    this.institutionPostId,
    this.directThreadId,
    this.post,
    this.institutionPost,
    required this.payload,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String recipientUserId;

  /// Wire string (LIKE / REPLY / REPOST / FOLLOW / MESSAGE / …).
  final String type;

  final ActorType actorType;
  final String? actorId;
  final String? actorInstitutionId;

  final Map<String, dynamic>? actor;
  final Map<String, dynamic>? actorInstitution;

  final String? postId;
  final String? institutionPostId;
  final String? directThreadId;

  final Map<String, dynamic>? post;
  final Map<String, dynamic>? institutionPost;

  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  /// Backend-stored deeplink. The notification creator places the canonical
  /// target route inside `payload.deeplink`; consumers should prefer this
  /// over rebuilding routes from individual fields. Returns null when the
  /// backend didn't ship one (older rows or kinds without a target).
  String? get deeplink {
    final raw = payload['deeplink'];
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  bool get isInstitutionVoice =>
      actorType == ActorType.institution &&
      actorInstitutionId != null &&
      actorInstitutionId!.isNotEmpty;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actorTypeRaw =
        (json['actorType'] ?? '').toString().trim().toUpperCase();
    return AppNotification(
      id: json['id']?.toString() ?? '',
      recipientUserId: json['recipientUserId']?.toString() ?? '',
      type: (json['type'] ?? '').toString().toUpperCase(),
      actorType: actorTypeRaw == 'INSTITUTION'
          ? ActorType.institution
          : ActorType.user,
      actorId: json['actorId']?.toString(),
      actorInstitutionId: json['actorInstitutionId']?.toString(),
      actor: json['actor'] is Map
          ? Map<String, dynamic>.from(json['actor'] as Map)
          : null,
      actorInstitution: json['actorInstitution'] is Map
          ? Map<String, dynamic>.from(json['actorInstitution'] as Map)
          : null,
      postId: json['postId']?.toString(),
      institutionPostId: json['institutionPostId']?.toString(),
      directThreadId: json['directThreadId']?.toString(),
      post: json['post'] is Map
          ? Map<String, dynamic>.from(json['post'] as Map)
          : null,
      institutionPost: json['institutionPost'] is Map
          ? Map<String, dynamic>.from(json['institutionPost'] as Map)
          : null,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
