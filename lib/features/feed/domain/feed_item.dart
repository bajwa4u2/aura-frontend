/// Unified feed item shape consumed by every feed surface in the app.
///
/// Mirrors the backend `FeedItemDto` produced by `FeedProjectionService`. A
/// single class deliberately holds both user-post and institution-post
/// content because every surface that lists posts (explore, profile, member
/// home, global feed, activity targets, notification targets) needs the same
/// fields to render and navigate. The discriminator [type] tells widgets
/// which representation to show.
library;

import 'feed_media.dart';
export 'feed_media.dart';

enum FeedItemType {
  userPost,
  institutionPost,
  announcement;

  /// Backend wire token for this type.
  String get wire {
    switch (this) {
      case FeedItemType.userPost:
        return 'USER_POST';
      case FeedItemType.institutionPost:
        return 'INSTITUTION_POST';
      case FeedItemType.announcement:
        return 'ANNOUNCEMENT';
    }
  }

  static FeedItemType fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    if (s == 'INSTITUTION_POST') return FeedItemType.institutionPost;
    if (s == 'ANNOUNCEMENT') return FeedItemType.announcement;
    return FeedItemType.userPost;
  }
}

enum FeedAuthorType {
  user,
  institution;

  String get wire {
    switch (this) {
      case FeedAuthorType.user:
        return 'USER';
      case FeedAuthorType.institution:
        return 'INSTITUTION';
    }
  }

  static FeedAuthorType fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    if (s == 'INSTITUTION') return FeedAuthorType.institution;
    return FeedAuthorType.user;
  }
}

enum FeedVisibility {
  public,
  memberOnly,
  internal,
  unknown;

  String get wire {
    switch (this) {
      case FeedVisibility.public:
        return 'PUBLIC';
      case FeedVisibility.memberOnly:
        return 'MEMBER_ONLY';
      case FeedVisibility.internal:
        return 'INTERNAL';
      case FeedVisibility.unknown:
        return '';
    }
  }

  static FeedVisibility fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    switch (s) {
      case 'PUBLIC':
        return FeedVisibility.public;
      case 'MEMBER_ONLY':
      case 'MEMBER':
      case 'MEMBERS':
        return FeedVisibility.memberOnly;
      case 'INTERNAL':
        return FeedVisibility.internal;
      default:
        return FeedVisibility.unknown;
    }
  }
}

enum FeedDistribution {
  globalEligible,
  institutionOnly;

  String get wire {
    switch (this) {
      case FeedDistribution.globalEligible:
        return 'GLOBAL_ELIGIBLE';
      case FeedDistribution.institutionOnly:
        return 'INSTITUTION_ONLY';
    }
  }

  static FeedDistribution fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    if (s == 'GLOBAL_ELIGIBLE') return FeedDistribution.globalEligible;
    return FeedDistribution.institutionOnly;
  }
}

/// Phase 6.1 — identity context describes *how* the author is speaking.
/// See backend `FeedIdentityContextDto` for the full spec. The frontend
/// renders this as a small label/badge under the author name; it never
/// becomes a count or popularity indicator.
enum FeedIdentityContextType {
  personal,
  officialInstitution,
  institutionMember,
  institutionAdmin,
  platformAdmin,
  unknown;

  static FeedIdentityContextType fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    switch (s) {
      case 'PERSONAL':
        return FeedIdentityContextType.personal;
      case 'OFFICIAL_INSTITUTION':
        return FeedIdentityContextType.officialInstitution;
      case 'INSTITUTION_MEMBER':
        return FeedIdentityContextType.institutionMember;
      case 'INSTITUTION_ADMIN':
        return FeedIdentityContextType.institutionAdmin;
      case 'PLATFORM_ADMIN':
        return FeedIdentityContextType.platformAdmin;
      default:
        return FeedIdentityContextType.unknown;
    }
  }
}

class FeedIdentityContext {
  const FeedIdentityContext({
    required this.type,
    required this.label,
    this.institutionId,
    this.institutionName,
    this.institutionSlug,
    this.role,
    this.verified = false,
  });

  final FeedIdentityContextType type;
  final String label;
  final String? institutionId;
  final String? institutionName;
  final String? institutionSlug;
  final String? role;
  final bool verified;

  /// True for context types that warrant a visible chip (everything except
  /// personal-with-no-extra-data, which is the implied default and would
  /// only add noise to render).
  bool get isMeaningful =>
      type != FeedIdentityContextType.personal &&
      type != FeedIdentityContextType.unknown;

  factory FeedIdentityContext.fromJson(Map<String, dynamic> m) {
    String? opt(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    return FeedIdentityContext(
      type: FeedIdentityContextType.fromWire(m['type']),
      label: opt(['label']) ?? '',
      institutionId: opt(['institutionId']),
      institutionName: opt(['institutionName']),
      institutionSlug: opt(['institutionSlug']),
      role: opt(['role']),
      verified: m['verified'] == true,
    );
  }
}

/// Phase 6.2 — calm freshness signal. Backend derives state from
/// `lastActiveAt` against fixed thresholds; the frontend renders a small
/// dot for everything except `idle`, which goes silent.
enum FeedPresenceState {
  activeNow,
  recentlyActive,
  activeToday,
  idle,
  unknown;

  static FeedPresenceState fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    switch (s) {
      case 'ACTIVE_NOW':
        return FeedPresenceState.activeNow;
      case 'RECENTLY_ACTIVE':
        return FeedPresenceState.recentlyActive;
      case 'ACTIVE_TODAY':
        return FeedPresenceState.activeToday;
      case 'IDLE':
        return FeedPresenceState.idle;
      default:
        return FeedPresenceState.unknown;
    }
  }

  bool get hasDot =>
      this == FeedPresenceState.activeNow ||
      this == FeedPresenceState.recentlyActive ||
      this == FeedPresenceState.activeToday;
}

class FeedPresence {
  const FeedPresence({required this.state, this.lastActiveAt});

  final FeedPresenceState state;
  final DateTime? lastActiveAt;

  factory FeedPresence.fromJson(Map<String, dynamic> m) {
    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return FeedPresence(
      state: FeedPresenceState.fromWire(m['state']),
      lastActiveAt: readDate(m['lastActiveAt']),
    );
  }
}

/// Phase 6.4 — calm voice indicator. "Official" / "Member contribution" /
/// nothing (personal). Rendered as a tiny muted line below the secondary
/// attribution. Never carries a count or icon.
enum FeedVoiceType {
  official,
  member,
  personal,
  unknown;

  static FeedVoiceType fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    switch (s) {
      case 'OFFICIAL':
        return FeedVoiceType.official;
      case 'MEMBER':
        return FeedVoiceType.member;
      case 'PERSONAL':
        return FeedVoiceType.personal;
      default:
        return FeedVoiceType.unknown;
    }
  }

  /// Whether this voice deserves a visible label. Personal is the default
  /// tone and renders nothing.
  bool get rendersLabel =>
      this == FeedVoiceType.official || this == FeedVoiceType.member;
}

class FeedVoice {
  const FeedVoice({required this.type, required this.label});

  final FeedVoiceType type;
  final String label;

  factory FeedVoice.fromJson(Map<String, dynamic> m) {
    return FeedVoice(
      type: FeedVoiceType.fromWire(m['type']),
      label: (m['label'] ?? '').toString(),
    );
  }
}

/// Phase 6.3 — accountable human actor for institution-voice posts.
///
/// Rendered as a small muted line below the primary author row. The
/// primary `FeedItem.author` stays the institution; this is the secondary
/// "Posted by Founder · M S Bajwa" attribution. Absent when the primary
/// author is a person, when the institution post has no human author
/// loaded, or when the actor is incomplete.
enum FeedSecondaryAttributionType {
  postedBy,
  repostedBy,
  respondedBy,
  unknown;

  static FeedSecondaryAttributionType fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    switch (s) {
      case 'POSTED_BY':
        return FeedSecondaryAttributionType.postedBy;
      case 'REPOSTED_BY':
        return FeedSecondaryAttributionType.repostedBy;
      case 'RESPONDED_BY':
        return FeedSecondaryAttributionType.respondedBy;
      default:
        return FeedSecondaryAttributionType.unknown;
    }
  }

  String get verb {
    switch (this) {
      case FeedSecondaryAttributionType.postedBy:
        return 'Posted by';
      case FeedSecondaryAttributionType.repostedBy:
        return 'Reposted by';
      case FeedSecondaryAttributionType.respondedBy:
        return 'Responded by';
      case FeedSecondaryAttributionType.unknown:
        return '';
    }
  }
}

class FeedSecondaryActor {
  const FeedSecondaryActor({
    required this.id,
    required this.displayName,
    this.handle,
    this.avatarUrl,
    this.profileRoute,
    this.context,
    this.presence,
  });

  final String id;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final String? profileRoute;
  final FeedIdentityContext? context;
  final FeedPresence? presence;

  factory FeedSecondaryActor.fromJson(Map<String, dynamic> m) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? opt(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    final ctxRaw = m['context'];
    final ctx = ctxRaw is Map
        ? FeedIdentityContext.fromJson(Map<String, dynamic>.from(ctxRaw))
        : null;

    final presenceRaw = m['presence'];
    final presence = presenceRaw is Map
        ? FeedPresence.fromJson(Map<String, dynamic>.from(presenceRaw))
        : null;

    return FeedSecondaryActor(
      id: s(['id']),
      displayName: s(['displayName']),
      handle: opt(['handle']),
      avatarUrl: opt(['avatarUrl']),
      profileRoute: opt(['profileRoute']),
      context: ctx,
      presence: presence,
    );
  }
}

class FeedSecondaryAttribution {
  const FeedSecondaryAttribution({required this.type, required this.actor});

  final FeedSecondaryAttributionType type;
  final FeedSecondaryActor actor;

  factory FeedSecondaryAttribution.fromJson(Map<String, dynamic> m) {
    final actorRaw = m['actor'];
    final actor = actorRaw is Map
        ? FeedSecondaryActor.fromJson(Map<String, dynamic>.from(actorRaw))
        : const FeedSecondaryActor(id: '', displayName: '');
    return FeedSecondaryAttribution(
      type: FeedSecondaryAttributionType.fromWire(m['type']),
      actor: actor,
    );
  }
}

/// Phase 6.2 — calm activity hint. `recentReply` is the only flag the UI
/// reads today; the timestamp is exposed for surfaces that want a softer
/// "last reply 23m ago" copy without re-fetching.
class FeedActivityHint {
  const FeedActivityHint({this.lastReplyAt, this.recentReply = false});

  final DateTime? lastReplyAt;
  final bool recentReply;

  factory FeedActivityHint.fromJson(Map<String, dynamic> m) {
    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return FeedActivityHint(
      lastReplyAt: readDate(m['lastReplyAt']),
      recentReply: m['recentReply'] == true,
    );
  }
}

class FeedAuthor {
  const FeedAuthor({
    required this.id,
    required this.type,
    required this.name,
    required this.handleOrSlug,
    this.avatarOrLogoUrl,
    this.profileRoute,
    this.context,
    this.presence,
  });

  final String id;
  final FeedAuthorType type;
  final String name;
  final String handleOrSlug;
  final String? avatarOrLogoUrl;

  /// Canonical profile route (e.g. `/u/{handle}`, `/institutions/{slug}`).
  /// Surfaces inside an institution shell may rewrite this to keep shell
  /// context — see `FeedRouting.adaptProfileRoute`.
  final String? profileRoute;

  /// Phase 6.1 — identity context (Personal / Official / Member / Admin).
  /// Optional and additive; older payloads parse to null.
  final FeedIdentityContext? context;

  /// Phase 6.2 — presence freshness. Optional; null when no presence row
  /// exists for this actor.
  final FeedPresence? presence;

  bool get isInstitution => type == FeedAuthorType.institution;

  factory FeedAuthor.fromJson(Map<String, dynamic> m) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? opt(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    final ctxRaw = m['context'];
    final ctx = ctxRaw is Map
        ? FeedIdentityContext.fromJson(Map<String, dynamic>.from(ctxRaw))
        : null;

    final presenceRaw = m['presence'];
    final presence = presenceRaw is Map
        ? FeedPresence.fromJson(Map<String, dynamic>.from(presenceRaw))
        : null;

    return FeedAuthor(
      id: s(['id']),
      type: FeedAuthorType.fromWire(m['type']),
      name: s(['name']),
      handleOrSlug: s(['handleOrSlug', 'handle', 'slug']),
      avatarOrLogoUrl: opt(['avatarOrLogoUrl', 'avatarUrl', 'logoUrl']),
      profileRoute: opt(['profileRoute']),
      context: ctx,
      presence: presence,
    );
  }
}

class FeedInteraction {
  const FeedInteraction({
    required this.likeCount,
    required this.replyCount,
    required this.repostCount,
    required this.viewerLiked,
    required this.canViewLikeCount,
    required this.canViewReplyCount,
    required this.canViewRepostCount,
  });

  final int likeCount;
  final int replyCount;
  final int repostCount;
  final bool viewerLiked;

  /// Aura interaction-visibility flags. Counts are signals, not scores —
  /// like/repost counts are private to the post's author / institution
  /// owner-admin-editor; reply counts are public for visible items. UI
  /// surfaces must consult these flags before rendering any number.
  final bool canViewLikeCount;
  final bool canViewReplyCount;
  final bool canViewRepostCount;

  factory FeedInteraction.fromJson(Map<String, dynamic> m) {
    int readInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString().trim()) ?? 0;
    }

    return FeedInteraction(
      likeCount: readInt(m['likeCount']),
      replyCount: readInt(m['replyCount']),
      repostCount: readInt(m['repostCount']),
      viewerLiked: m['viewerLiked'] == true,
      // Default closed: a missing/legacy flag must NEVER expose a count to
      // a viewer who shouldn't see it. The reply-count flag is opened by
      // the backend for every visible item; older payloads without flags
      // therefore correctly hide everything.
      canViewLikeCount: m['canViewLikeCount'] == true,
      canViewReplyCount: m['canViewReplyCount'] == true,
      canViewRepostCount: m['canViewRepostCount'] == true,
    );
  }

  static const empty = FeedInteraction(
    likeCount: 0,
    replyCount: 0,
    repostCount: 0,
    viewerLiked: false,
    canViewLikeCount: false,
    canViewReplyCount: false,
    canViewRepostCount: false,
  );
}

/// Phase 5.1 — minimal conversation depth shown under a feed card.
///
/// `items` is at most 2 of the parent's earliest replies. `hasMore` tells
/// the UI whether to render a "View discussion" affordance that opens the
/// full reply list in the post-detail screen.
class FeedReplyPreview {
  const FeedReplyPreview({required this.items, required this.hasMore});

  final List<FeedReplyPreviewItem> items;
  final bool hasMore;

  bool get isEmpty => items.isEmpty;

  factory FeedReplyPreview.fromJson(Map<String, dynamic> m) {
    final raw = m['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) =>
                FeedReplyPreviewItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <FeedReplyPreviewItem>[];
    return FeedReplyPreview(
      items: items,
      hasMore: m['hasMore'] == true,
    );
  }
}

class FeedReplyPreviewItem {
  const FeedReplyPreviewItem({
    required this.id,
    required this.body,
    required this.author,
    this.createdAt,
  });

  final String id;
  final String body;
  final FeedReplyPreviewAuthor author;
  final DateTime? createdAt;

  factory FeedReplyPreviewItem.fromJson(Map<String, dynamic> m) {
    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final authorRaw = m['author'];
    final author = authorRaw is Map
        ? FeedReplyPreviewAuthor.fromJson(
            Map<String, dynamic>.from(authorRaw),
          )
        : const FeedReplyPreviewAuthor(id: '', displayName: '');

    return FeedReplyPreviewItem(
      id: s(['id']),
      body: s(['body']),
      author: author,
      createdAt: readDate(m['createdAt']),
    );
  }
}

class FeedReplyPreviewAuthor {
  const FeedReplyPreviewAuthor({
    required this.id,
    required this.displayName,
    this.handle,
    this.avatarUrl,
    this.profileRoute,
    this.context,
    this.presence,
  });

  final String id;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final String? profileRoute;
  /// Phase 6.1.1 — optional identity context. Renders nothing when absent.
  final FeedIdentityContext? context;
  /// Phase 6.2 — presence freshness.
  final FeedPresence? presence;

  factory FeedReplyPreviewAuthor.fromJson(Map<String, dynamic> m) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? opt(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    final ctxRaw = m['context'];
    final ctx = ctxRaw is Map
        ? FeedIdentityContext.fromJson(Map<String, dynamic>.from(ctxRaw))
        : null;

    final presenceRaw = m['presence'];
    final presence = presenceRaw is Map
        ? FeedPresence.fromJson(Map<String, dynamic>.from(presenceRaw))
        : null;

    return FeedReplyPreviewAuthor(
      id: s(['id']),
      displayName: s(['displayName']),
      handle: opt(['handle']),
      avatarUrl: opt(['avatarUrl']),
      profileRoute: opt(['profileRoute']),
      context: ctx,
      presence: presence,
    );
  }
}

/// Phase 4: an actor that contributed a relevance signal to a feed item.
///
/// The actor is **not** the post's author — that lives on `FeedItem.author`.
/// Signal actors are people the viewer follows (or themselves) whose
/// repost surfaced the parent.
class FeedSignalActor {
  const FeedSignalActor({
    required this.id,
    required this.type,
    required this.displayName,
    this.handle,
    this.avatarUrl,
    this.isViewer = false,
  });

  final String id;
  final FeedAuthorType type;
  final String displayName;
  final String? handle;
  final String? avatarUrl;

  /// True when this actor is the viewer — clients render "You reposted"
  /// instead of the displayName.
  final bool isViewer;

  factory FeedSignalActor.fromJson(Map<String, dynamic> m) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? opt(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    return FeedSignalActor(
      id: s(['id']),
      type: FeedAuthorType.fromWire(m['type']),
      displayName: s(['displayName', 'name']),
      handle: opt(['handle']),
      avatarUrl: opt(['avatarUrl', 'avatarOrLogoUrl']),
      isViewer: m['isViewer'] == true,
    );
  }
}

/// Relevance signal attached to a feed item. Phase 4 currently emits only
/// `REPOST` signals; the wire format reserves room for future signal
/// kinds without breaking clients.
class FeedSignal {
  const FeedSignal({required this.type, required this.actors});

  final String type; // 'REPOST'
  final List<FeedSignalActor> actors;

  factory FeedSignal.fromJson(Map<String, dynamic> m) {
    final raw = m['actors'];
    final actors = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => FeedSignalActor.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <FeedSignalActor>[];
    return FeedSignal(
      type: (m['type'] ?? '').toString().toUpperCase(),
      actors: actors,
    );
  }
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.type,
    required this.authorType,
    required this.author,
    this.title,
    required this.body,
    this.mediaUrl,
    this.media = const <FeedMedia>[],
    required this.visibility,
    required this.distribution,
    required this.status,
    this.createdAt,
    this.publishedAt,
    required this.targetRoute,
    required this.interaction,
    this.signal,
    this.replyPreview,
    this.activity,
    this.secondaryAttribution,
    this.voice,
    this.paidActionWire,
    this.publicSpaceId,
    this.publicSpaceSlug,
    this.publicSpaceName,
  });

  final String id;
  final FeedItemType type;
  final FeedAuthorType authorType;
  final FeedAuthor author;
  final String? title;
  final String body;
  final String? mediaUrl;

  /// C4-followup — canonical media[] from the backend. Empty when no
  /// canonical link exists (legacy mediaUrl-only rows). Renderers
  /// should prefer this list over [mediaUrl] when populated and branch
  /// on each entry's visibility for signed-URL delivery.
  final List<FeedMedia> media;
  final FeedVisibility visibility;
  final FeedDistribution distribution;
  final String status;
  final DateTime? createdAt;
  final DateTime? publishedAt;

  /// Canonical detail route. Surfaces inside an institution shell may rewrite
  /// this via `FeedRouting.adaptTargetRoute`.
  final String targetRoute;
  final FeedInteraction interaction;

  /// Phase 4 — optional relevance signal (e.g. "Muhammad reposted"). Absent
  /// when the item surfaced through normal sources only.
  final FeedSignal? signal;

  /// Phase 5.1 — minimal conversation depth (≤2 replies + hasMore). Absent
  /// when the parent has no replies.
  final FeedReplyPreview? replyPreview;

  /// Phase 6.2 — calm activity hint. Absent when no recent activity exists.
  final FeedActivityHint? activity;

  /// Phase 6.3 — accountable human actor for institution-voice posts.
  /// Absent for personal posts and for institution posts with no human
  /// author available.
  final FeedSecondaryAttribution? secondaryAttribution;

  /// Phase 6.4 — calm voice indicator. Absent for personal posts; present
  /// only when the backend has data to back the label.
  final FeedVoice? voice;

  /// Public-UX Phase 3 — backend `paidAction` wire token (PRIORITY /
  /// HOSTED / DISTRIBUTED). Null for organic posts. Frontend resolves
  /// this to a `MonetizationKind` for in-context label rendering.
  final String? paidActionWire;

  /// Public-UX Phase 3 — anchoring to a public discourse space. Null
  /// when the post is unanchored. Slug + name are denormalized so the
  /// frontend doesn't need a second fetch to render the eyebrow chip.
  final String? publicSpaceId;
  final String? publicSpaceSlug;
  final String? publicSpaceName;

  bool get isInstitutionPost => type == FeedItemType.institutionPost;
  bool get isUserPost => type == FeedItemType.userPost;
  bool get isAnnouncement => type == FeedItemType.announcement;
  /// True for cards that speak with institutional voice — institution
  /// posts and institution announcements alike. Drives the OFFICIAL
  /// pill and disables personal-post-only affordances.
  bool get isInstitutionalVoice =>
      type == FeedItemType.institutionPost || type == FeedItemType.announcement;

  factory FeedItem.fromJson(Map<String, dynamic> m) {
    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? opt(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    final authorRaw = m['author'];
    final author = authorRaw is Map
        ? FeedAuthor.fromJson(Map<String, dynamic>.from(authorRaw))
        : const FeedAuthor(
            id: '',
            type: FeedAuthorType.user,
            name: '',
            handleOrSlug: '',
          );

    final interactionRaw = m['interaction'];
    final interaction = interactionRaw is Map
        ? FeedInteraction.fromJson(Map<String, dynamic>.from(interactionRaw))
        : FeedInteraction.empty;

    final signalRaw = m['signal'];
    final signal = signalRaw is Map
        ? FeedSignal.fromJson(Map<String, dynamic>.from(signalRaw))
        : null;

    final replyPreviewRaw = m['replyPreview'];
    final replyPreview = replyPreviewRaw is Map
        ? FeedReplyPreview.fromJson(
            Map<String, dynamic>.from(replyPreviewRaw),
          )
        : null;

    final activityRaw = m['activity'];
    final activity = activityRaw is Map
        ? FeedActivityHint.fromJson(Map<String, dynamic>.from(activityRaw))
        : null;

    final secondaryRaw = m['secondaryAttribution'];
    final secondaryAttribution = secondaryRaw is Map
        ? FeedSecondaryAttribution.fromJson(
            Map<String, dynamic>.from(secondaryRaw),
          )
        : null;

    final voiceRaw = m['voice'];
    final voice = voiceRaw is Map
        ? FeedVoice.fromJson(Map<String, dynamic>.from(voiceRaw))
        : null;

    // Public-UX Phase 3 — extract the optional space anchoring. The
    // space block may arrive as a nested map (`publicSpace: {…}`) or
    // as denormalized top-level keys.
    String? spaceId;
    String? spaceSlug;
    String? spaceName;
    final spaceRaw = m['publicSpace'];
    if (spaceRaw is Map) {
      spaceId = spaceRaw['id']?.toString().trim();
      spaceSlug = spaceRaw['slug']?.toString().trim();
      spaceName = spaceRaw['name']?.toString().trim();
    }
    spaceId ??= opt(['publicSpaceId']);
    spaceSlug ??= opt(['publicSpaceSlug']);
    spaceName ??= opt(['publicSpaceName']);

    return FeedItem(
      id: s(['id']),
      type: FeedItemType.fromWire(m['type']),
      authorType: FeedAuthorType.fromWire(m['authorType']),
      author: author,
      title: opt(['title']),
      body: s(['body']),
      mediaUrl: opt(['mediaUrl']),
      media: FeedMedia.listFromJson(m['media']),
      visibility: FeedVisibility.fromWire(m['visibility']),
      distribution: FeedDistribution.fromWire(m['distribution']),
      status: s(['status']),
      createdAt: readDate(m['createdAt']),
      publishedAt: readDate(m['publishedAt']),
      targetRoute: s(['targetRoute']),
      interaction: interaction,
      signal: signal,
      replyPreview: replyPreview,
      activity: activity,
      secondaryAttribution: secondaryAttribution,
      voice: voice,
      paidActionWire: opt(['paidAction']),
      publicSpaceId: spaceId,
      publicSpaceSlug: spaceSlug,
      publicSpaceName: spaceName,
    );
  }
}

/// Reply item returned by `GET /v1/feed/items/:type/:id/replies`.
///
/// Replies use a deliberately leaner shape than [FeedItem]: they carry only
/// what the reply UI needs (body, optional media, author + profile route)
/// instead of the full visibility/distribution/interaction surface. Counts
/// for replies-of-replies aren't expressed today; if that becomes a feature
/// we'll add an `interaction` block here too.
class FeedReply {
  const FeedReply({
    required this.id,
    required this.body,
    this.mediaUrl,
    required this.author,
    this.createdAt,
    this.updatedAt,
    this.parentReplyId,
    this.accountabilityTagWire,
    this.paidActionWire,
  });

  final String id;
  final String body;
  final String? mediaUrl;
  final FeedReplyAuthor author;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Public-UX Phase 3 — parent-reply pointer for nested replies. Null
  /// for top-level replies (replies directly under the parent post).
  /// The frontend renders nested children up to a depth cap of 2.
  /// Wire: `parentReplyId` — the existing `replyToPostId` /
  /// `replyToInstitutionPostId` self-pointer surfaced as a
  /// type-agnostic field name so the same code path handles both.
  final String? parentReplyId;

  /// Public-UX Phase 3 — institution-set accountability tag
  /// (COMMITMENT / UPDATE / RESOLVED). Null for unset replies.
  final String? accountabilityTagWire;

  /// Public-UX Phase 3 — backend `paidAction` wire token
  /// (PRIORITY / HOSTED / DISTRIBUTED). Null for organic replies.
  final String? paidActionWire;

  factory FeedReply.fromJson(Map<String, dynamic> m) {
    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? opt(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    final authorRaw = m['author'];
    final author = authorRaw is Map
        ? FeedReplyAuthor.fromJson(Map<String, dynamic>.from(authorRaw))
        : const FeedReplyAuthor(id: '', displayName: '', handle: '');

    return FeedReply(
      id: s(['id']),
      body: s(['body']),
      mediaUrl: opt(['mediaUrl']),
      author: author,
      createdAt: readDate(m['createdAt']),
      updatedAt: readDate(m['updatedAt']),
      parentReplyId: opt([
        'parentReplyId',
        'replyToPostId',
        'replyToInstitutionPostId',
      ]),
      accountabilityTagWire: opt(['accountabilityTag']),
      paidActionWire: opt(['paidAction']),
    );
  }
}

class FeedReplyAuthor {
  const FeedReplyAuthor({
    required this.id,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    this.profileRoute,
    this.context,
    this.presence,
  });

  final String id;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final String? profileRoute;
  /// Phase 6.1.1 — optional identity context. Renders nothing when absent.
  final FeedIdentityContext? context;
  /// Phase 6.2 — presence freshness.
  final FeedPresence? presence;

  factory FeedReplyAuthor.fromJson(Map<String, dynamic> m) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? opt(List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    final ctxRaw = m['context'];
    final ctx = ctxRaw is Map
        ? FeedIdentityContext.fromJson(Map<String, dynamic>.from(ctxRaw))
        : null;

    final presenceRaw = m['presence'];
    final presence = presenceRaw is Map
        ? FeedPresence.fromJson(Map<String, dynamic>.from(presenceRaw))
        : null;

    return FeedReplyAuthor(
      id: s(['id']),
      displayName: s(['displayName', 'name']),
      handle: s(['handle']),
      avatarUrl: opt(['avatarUrl', 'avatarOrLogoUrl']),
      profileRoute: opt(['profileRoute']),
      context: ctx,
      presence: presence,
    );
  }
}

class FeedRepliesPage {
  const FeedRepliesPage({required this.items, this.nextCursor});

  final List<FeedReply> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory FeedRepliesPage.fromJson(dynamic body) {
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final container = root['data'] is Map
          ? Map<String, dynamic>.from(root['data'] as Map)
          : root;
      final raw = container['items'];
      final items = <FeedReply>[];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          items.add(FeedReply.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
      String? next;
      final cur = container['nextCursor'];
      if (cur != null) {
        final s = cur.toString().trim();
        if (s.isNotEmpty) next = s;
      }
      return FeedRepliesPage(items: items, nextCursor: next);
    }
    return const FeedRepliesPage(items: <FeedReply>[]);
  }
}

class FeedPage {
  const FeedPage({required this.items, this.nextCursor});

  final List<FeedItem> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  factory FeedPage.fromJson(dynamic body) {
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      // Tolerate both the bare shape and a `{ ok, data }` envelope so this
      // parser works in front of every endpoint that emits FeedItem-shaped
      // responses, including the older /posts/public surface if a caller
      // routes it through here.
      final container = (root['data'] is Map)
          ? Map<String, dynamic>.from(root['data'] as Map)
          : root;
      final raw = container['items'];
      final items = <FeedItem>[];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          items.add(FeedItem.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
      String? next;
      final cur = container['nextCursor'];
      if (cur != null) {
        final s = cur.toString().trim();
        if (s.isNotEmpty) next = s;
      }
      return FeedPage(items: items, nextCursor: next);
    }
    return const FeedPage(items: <FeedItem>[]);
  }
}

/// Shell-aware route adapter for FeedItem `targetRoute` and
/// `author.profileRoute`. Pure function; no side effects.
class FeedRouting {
  /// When the caller is inside an institution shell (path begins with
  /// `/institution/:id/...`), rewrites a canonical `targetRoute` so the user
  /// stays in that shell after navigation. Otherwise returns the route
  /// unchanged.
  static String adaptTargetRoute(String canonical, {String? currentPath}) {
    return _adapt(canonical, currentPath);
  }

  static String? adaptProfileRoute(String? canonical, {String? currentPath}) {
    if (canonical == null || canonical.isEmpty) return canonical;
    return _adapt(canonical, currentPath);
  }

  static String _adapt(String canonical, String? currentPath) {
    final cp = (currentPath ?? '').trim();
    if (cp.isEmpty || !cp.startsWith('/institution/')) return canonical;
    final m = RegExp(r'^/institution/([^/]+)').firstMatch(cp);
    if (m == null) return canonical;
    final institutionId = m.group(1) ?? '';
    if (institutionId.isEmpty) return canonical;
    if (canonical.startsWith('/institution/')) return canonical;
    if (!canonical.startsWith('/')) return canonical;
    return '/institution/$institutionId$canonical';
  }
}
