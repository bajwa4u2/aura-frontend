/// Domain model for the rebuilt InstitutionPost surface.
///
/// Mirrors the backend contract:
///   InstitutionPost = {
///     id, institutionId, authorUserId, title, body, mediaUrl?,
///     media: FeedMedia[],   // C4-followup — canonical media[]
///     visibility: 'PUBLIC' | 'MEMBER_ONLY' | 'INTERNAL',
///     distribution: 'INSTITUTION_ONLY' | 'GLOBAL_ELIGIBLE',
///     status: 'DRAFT' | 'PENDING_APPROVAL' | 'PUBLISHED' | 'ARCHIVED',
///     publishedAt, archivedAt, createdAt, updatedAt
///   }
///
/// `distribution` may only be `GLOBAL_ELIGIBLE` when `visibility` is `PUBLIC`.
library;

import '../../feed/domain/feed_media.dart';
export '../../feed/domain/feed_media.dart' show FeedMedia;

enum InstitutionPostVisibility { publicAll, memberOnly, internal }

extension InstitutionPostVisibilityX on InstitutionPostVisibility {
  String get wire {
    switch (this) {
      case InstitutionPostVisibility.publicAll:
        return 'PUBLIC';
      case InstitutionPostVisibility.memberOnly:
        return 'MEMBER_ONLY';
      case InstitutionPostVisibility.internal:
        return 'INTERNAL';
    }
  }

  String get label {
    switch (this) {
      case InstitutionPostVisibility.publicAll:
        return 'Public';
      case InstitutionPostVisibility.memberOnly:
        return 'Members only';
      case InstitutionPostVisibility.internal:
        return 'Internal (admins/editors)';
    }
  }

  static InstitutionPostVisibility fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    switch (s) {
      case 'MEMBER_ONLY':
      case 'MEMBER':
      case 'MEMBERS':
        return InstitutionPostVisibility.memberOnly;
      case 'INTERNAL':
        return InstitutionPostVisibility.internal;
      case 'PUBLIC':
      default:
        return InstitutionPostVisibility.publicAll;
    }
  }
}

enum InstitutionPostDistribution { institutionOnly, globalEligible }

extension InstitutionPostDistributionX on InstitutionPostDistribution {
  String get wire {
    switch (this) {
      case InstitutionPostDistribution.institutionOnly:
        return 'INSTITUTION_ONLY';
      case InstitutionPostDistribution.globalEligible:
        return 'GLOBAL_ELIGIBLE';
    }
  }

  String get label {
    switch (this) {
      case InstitutionPostDistribution.institutionOnly:
        return 'Institution only';
      case InstitutionPostDistribution.globalEligible:
        return 'Eligible for global feed';
    }
  }

  static InstitutionPostDistribution fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    if (s == 'GLOBAL_ELIGIBLE' || s == 'GLOBAL') {
      return InstitutionPostDistribution.globalEligible;
    }
    return InstitutionPostDistribution.institutionOnly;
  }
}

enum InstitutionPostStatus { draft, pendingApproval, published, archived }

extension InstitutionPostStatusX on InstitutionPostStatus {
  String get wire {
    switch (this) {
      case InstitutionPostStatus.draft:
        return 'DRAFT';
      case InstitutionPostStatus.pendingApproval:
        return 'PENDING_APPROVAL';
      case InstitutionPostStatus.published:
        return 'PUBLISHED';
      case InstitutionPostStatus.archived:
        return 'ARCHIVED';
    }
  }

  String get label {
    switch (this) {
      case InstitutionPostStatus.draft:
        return 'Draft';
      case InstitutionPostStatus.pendingApproval:
        return 'Pending approval';
      case InstitutionPostStatus.published:
        return 'Published';
      case InstitutionPostStatus.archived:
        return 'Archived';
    }
  }

  static InstitutionPostStatus fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    switch (s) {
      case 'PENDING_APPROVAL':
      case 'PENDING':
        return InstitutionPostStatus.pendingApproval;
      case 'PUBLISHED':
        return InstitutionPostStatus.published;
      case 'ARCHIVED':
        return InstitutionPostStatus.archived;
      case 'DRAFT':
      default:
        return InstitutionPostStatus.draft;
    }
  }
}

class InstitutionPost {
  const InstitutionPost({
    required this.id,
    required this.institutionId,
    required this.authorUserId,
    required this.title,
    required this.body,
    this.mediaUrl,
    this.media = const <FeedMedia>[],
    required this.visibility,
    required this.distribution,
    required this.status,
    this.publishedAt,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
    this.author,
    this.institution,
    this.actorInstitutionId,
    this.actorInstitution,
    this.replyToInstitutionPostId,
    this.resolvesInstitutionPostId,
    this.continuesInstitutionPostId,
    this.primaryTopic,
    this.secondaryTopics = const <String>[],
  });

  final String id;
  final String institutionId;
  final String authorUserId;
  final String title;
  final String body;
  final String? mediaUrl;

  /// C4-followup — canonical media[] from the backend. Empty when no
  /// canonical link exists (legacy mediaUrl-only rows). Renderers
  /// should prefer this list over [mediaUrl] when populated and branch
  /// on each entry's `visibility` for signed-URL delivery.
  final List<FeedMedia> media;
  final InstitutionPostVisibility visibility;
  final InstitutionPostDistribution distribution;
  final InstitutionPostStatus status;
  final DateTime? publishedAt;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Optional embedded author summary (display name, handle, avatarUrl)
  /// when the API returns it as a sibling object.
  final Map<String, dynamic>? author;

  /// Embedded summary of the **feed** institution that owns this post (where
  /// it lives). Distinct from [actorInstitution] which is the speaking actor
  /// on a cross-institution reply.
  final Map<String, dynamic>? institution;

  /// When set, the institution speaking through this post (post is attributed
  /// to this institution rather than the personal author).
  final String? actorInstitutionId;
  final Map<String, dynamic>? actorInstitution;

  /// Set when this post is a reply under another InstitutionPost.
  final String? replyToInstitutionPostId;

  /// Phase 5 (R7) — participation memory. When set, this post is an
  /// explicit resolution of the referenced post. Backend-emitted via
  /// the institution-post API projection; null on posts without a
  /// resolution linkage. The frontend renders a calm "Resolves"
  /// indicator on the detail header.
  final String? resolvesInstitutionPostId;

  /// Phase 5 (R7) — explicit follow-up pointer for cross-thread
  /// continuations. When set, this post continues an earlier
  /// discussion identified by the referenced post id.
  final String? continuesInstitutionPostId;
  final String? primaryTopic;
  final List<String> secondaryTopics;

  bool get isReply =>
      replyToInstitutionPostId != null &&
      replyToInstitutionPostId!.trim().isNotEmpty;

  bool get hasContinuityLinkage =>
      (resolvesInstitutionPostId != null &&
          resolvesInstitutionPostId!.trim().isNotEmpty) ||
      (continuesInstitutionPostId != null &&
          continuesInstitutionPostId!.trim().isNotEmpty);

  bool get isInstitutionActor =>
      actorInstitutionId != null && actorInstitutionId!.trim().isNotEmpty;

  static const int maxTitleChars = 160;
  static const int maxBodyChars = 10000;

  /// Returns a user-facing message when [visibility]/[distribution] form
  /// an invalid combination. Returns null when the combination is valid.
  ///
  /// Rule: distribution=GLOBAL_ELIGIBLE only valid when visibility=PUBLIC.
  static String? validate(
    InstitutionPostVisibility visibility,
    InstitutionPostDistribution distribution,
  ) {
    if (distribution == InstitutionPostDistribution.globalEligible &&
        visibility != InstitutionPostVisibility.publicAll) {
      return 'Distribution can only be set to "Eligible for global feed" '
          'when visibility is Public.';
    }
    return null;
  }

  factory InstitutionPost.fromJson(Map<String, dynamic> json) {
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

    final author = json['author'];
    final institution = json['institution'];
    final actorInstitution = json['actorInstitution'];

    return InstitutionPost(
      id: s(['id']),
      institutionId: s(['institutionId']),
      authorUserId: s(['authorUserId', 'authorId']),
      title: s(['title']),
      body: s(['body', 'bodyMarkdown']),
      mediaUrl: opt(['mediaUrl']),
      media: FeedMedia.listFromJson(json['media']),
      visibility: InstitutionPostVisibilityX.fromWire(json['visibility']),
      distribution: InstitutionPostDistributionX.fromWire(json['distribution']),
      status: InstitutionPostStatusX.fromWire(json['status']),
      publishedAt: readDate(json['publishedAt']),
      archivedAt: readDate(json['archivedAt']),
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
      author: author is Map ? Map<String, dynamic>.from(author) : null,
      institution: institution is Map
          ? Map<String, dynamic>.from(institution)
          : null,
      actorInstitutionId: opt(['actorInstitutionId']),
      actorInstitution: actorInstitution is Map
          ? Map<String, dynamic>.from(actorInstitution)
          : null,
      replyToInstitutionPostId: opt(['replyToInstitutionPostId']),
      resolvesInstitutionPostId: opt(['resolvesInstitutionPostId']),
      continuesInstitutionPostId: opt(['continuesInstitutionPostId']),
      primaryTopic: opt(['primaryTopic']),
      secondaryTopics: (json['secondaryTopics'] is List)
          ? (json['secondaryTopics'] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'institutionId': institutionId,
      'authorUserId': authorUserId,
      'title': title,
      'body': body,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      'visibility': visibility.wire,
      'distribution': distribution.wire,
      'status': status.wire,
      if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
      if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (primaryTopic != null) 'primaryTopic': primaryTopic,
      if (secondaryTopics.isNotEmpty) 'secondaryTopics': secondaryTopics,
    };
  }
}
