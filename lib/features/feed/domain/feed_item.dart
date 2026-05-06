/// Unified feed item shape consumed by every feed surface in the app.
///
/// Mirrors the backend `FeedItemDto` produced by `FeedProjectionService`. A
/// single class deliberately holds both user-post and institution-post
/// content because every surface that lists posts (explore, profile, member
/// home, global feed, activity targets, notification targets) needs the same
/// fields to render and navigate. The discriminator [type] tells widgets
/// which representation to show.
library;

enum FeedItemType {
  userPost,
  institutionPost;

  /// Backend wire token for this type.
  String get wire {
    switch (this) {
      case FeedItemType.userPost:
        return 'USER_POST';
      case FeedItemType.institutionPost:
        return 'INSTITUTION_POST';
    }
  }

  static FeedItemType fromWire(dynamic raw) {
    final s = (raw ?? '').toString().trim().toUpperCase();
    if (s == 'INSTITUTION_POST') return FeedItemType.institutionPost;
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

class FeedAuthor {
  const FeedAuthor({
    required this.id,
    required this.type,
    required this.name,
    required this.handleOrSlug,
    this.avatarOrLogoUrl,
    this.profileRoute,
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

    return FeedAuthor(
      id: s(['id']),
      type: FeedAuthorType.fromWire(m['type']),
      name: s(['name']),
      handleOrSlug: s(['handleOrSlug', 'handle', 'slug']),
      avatarOrLogoUrl: opt(['avatarOrLogoUrl', 'avatarUrl', 'logoUrl']),
      profileRoute: opt(['profileRoute']),
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
    required this.visibility,
    required this.distribution,
    required this.status,
    this.createdAt,
    this.publishedAt,
    required this.targetRoute,
    required this.interaction,
    this.signal,
  });

  final String id;
  final FeedItemType type;
  final FeedAuthorType authorType;
  final FeedAuthor author;
  final String? title;
  final String body;
  final String? mediaUrl;
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

  bool get isInstitutionPost => type == FeedItemType.institutionPost;
  bool get isUserPost => type == FeedItemType.userPost;

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

    return FeedItem(
      id: s(['id']),
      type: FeedItemType.fromWire(m['type']),
      authorType: FeedAuthorType.fromWire(m['authorType']),
      author: author,
      title: opt(['title']),
      body: s(['body']),
      mediaUrl: opt(['mediaUrl']),
      visibility: FeedVisibility.fromWire(m['visibility']),
      distribution: FeedDistribution.fromWire(m['distribution']),
      status: s(['status']),
      createdAt: readDate(m['createdAt']),
      publishedAt: readDate(m['publishedAt']),
      targetRoute: s(['targetRoute']),
      interaction: interaction,
      signal: signal,
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
  });

  final String id;
  final String body;
  final String? mediaUrl;
  final FeedReplyAuthor author;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
  });

  final String id;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final String? profileRoute;

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

    return FeedReplyAuthor(
      id: s(['id']),
      displayName: s(['displayName', 'name']),
      handle: s(['handle']),
      avatarUrl: opt(['avatarUrl', 'avatarOrLogoUrl']),
      profileRoute: opt(['profileRoute']),
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
