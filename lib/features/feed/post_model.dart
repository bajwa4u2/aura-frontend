class PostAuthor {
  final String id;
  final String handle;
  final String displayName;
  final String? avatarUrl;

  const PostAuthor({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
  });

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String _asStringReq(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static String? _asStringOpt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory PostAuthor.fromJson(dynamic json) {
    final m = _asMap(json) ?? const <String, dynamic>{};
    return PostAuthor(
      id: _asStringReq(m['id']),
      handle: _asStringReq(m['handle']),
      displayName: _asStringReq(m['displayName']),
      avatarUrl: _asStringOpt(m['avatarUrl']),
    );
  }
}

class PostMedia {
  final String id;
  final String type; // IMAGE | VIDEO | SVG | OTHER (backend enum)
  final String url;
  final String? thumbUrl;
  final int? width;
  final int? height;
  final int? duration;
  final String? caption;

  const PostMedia({
    required this.id,
    required this.type,
    required this.url,
    this.thumbUrl,
    this.width,
    this.height,
    this.duration,
    this.caption,
  });

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String _asStringReq(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static String? _asStringOpt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _asInt(dynamic v) {
    if (v is num) return v.toInt();
    final s = _asStringOpt(v);
    if (s == null) return null;
    return int.tryParse(s);
  }

  factory PostMedia.fromJson(dynamic json) {
    final m = _asMap(json) ?? const <String, dynamic>{};
    return PostMedia(
      id: _asStringReq(m['id']),
      type: _asStringReq(m['type'], fallback: 'OTHER'),
      url: _asStringReq(m['url']),
      thumbUrl: _asStringOpt(m['thumbUrl']),
      width: _asInt(m['width']),
      height: _asInt(m['height']),
      duration: _asInt(m['duration']),
      caption: _asStringOpt(m['caption']),
    );
  }
}

class Post {
  final String id;
  final String text;
  final DateTime createdAt;

  // Author (new)
  final PostAuthor? author;

  // Back-compat (kept)
  final String authorHandle;

  // Visibility contract fields (new)
  final String? status; // DRAFT | PUBLISHED
  final String? visibility; // PUBLIC | FOLLOWERS | PRIVATE
  final String? replyToPostId;
  final String? repostOfPostId;

  // Media (back-compat + new)
  // mediaType: keep older UI assumptions: NONE | IMAGE | VIDEO | LINK
  final String mediaType;
  final String? mediaUrl;
  final String? mediaThumbUrl;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? mediaDuration;
  final String? caption;

  // Full media list (new, optional use)
  final List<PostMedia> media;

  // Link preview (optional)
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;

  Post({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.authorHandle,
    required this.mediaType,
    this.author,
    this.status,
    this.visibility,
    this.replyToPostId,
    this.repostOfPostId,
    this.mediaUrl,
    this.mediaThumbUrl,
    this.mediaWidth,
    this.mediaHeight,
    this.mediaDuration,
    this.caption,
    this.media = const <PostMedia>[],
    this.linkTitle,
    this.linkDescription,
    this.linkImageUrl,
  });

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _asInt(dynamic v) {
    if (v is num) return v.toInt();
    final s = _asString(v);
    if (s == null) return null;
    return int.tryParse(s);
  }

  static DateTime _asDate(dynamic v) {
    if (v is DateTime) return v;
    final s = _asString(v);
    if (s == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static List<PostMedia> _parseMediaList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => PostMedia.fromJson(e))
          .where((m) => m.url.trim().isNotEmpty)
          .toList();
    }
    return const <PostMedia>[];
  }

  static String _deriveMediaTypeFromPrimary(PostMedia? m) {
    if (m == null) return 'NONE';
    final t = m.type.toUpperCase();
    if (t.contains('VIDEO')) return 'VIDEO';
    if (t.contains('IMAGE') || t.contains('SVG')) return 'IMAGE';
    return 'OTHER';
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    final authorMap = _asMap(json['author']);
    final author = authorMap != null ? PostAuthor.fromJson(authorMap) : null;

    // New backend: media is a list
    final mediaList = _parseMediaList(json['media']);

    // Support older shapes too:
    final mediaMap = _asMap(json['media']); // legacy if media was an object
    PostMedia? primaryFromLegacyMap;
    if (mediaMap != null && mediaList.isEmpty) {
      // tolerate: { url, type, ... }
      primaryFromLegacyMap = PostMedia.fromJson(mediaMap);
    }

    final primary = mediaList.isNotEmpty ? mediaList.first : primaryFromLegacyMap;

    // Back-compat: flat media fields
    final flatMediaType = _asString(json['mediaType']);
    final derivedType = _deriveMediaTypeFromPrimary(primary);

    final mediaType = (flatMediaType ?? derivedType).trim().isEmpty
        ? 'NONE'
        : (flatMediaType ?? derivedType);

    final mediaUrl = _asString(json['mediaUrl']) ?? _asString(primary?.url);
    final mediaThumbUrl = _asString(json['mediaThumbUrl']) ?? _asString(primary?.thumbUrl);

    final mediaWidth = _asInt(json['mediaWidth']) ?? _asInt(primary?.width);
    final mediaHeight = _asInt(json['mediaHeight']) ?? _asInt(primary?.height);
    final mediaDuration = _asInt(json['mediaDuration']) ?? _asInt(primary?.duration);

    final caption = _asString(json['caption']) ?? _asString(primary?.caption);

    final handle = author?.handle ?? _asString(authorMap?['handle']) ?? '';
    final authorHandle = handle;

    return Post(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: _asDate(json['createdAt']),
      author: author,
      authorHandle: authorHandle,
      status: _asString(json['status']),
      visibility: _asString(json['visibility']),
      replyToPostId: _asString(json['replyToPostId']),
      repostOfPostId: _asString(json['repostOfPostId']),
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      mediaThumbUrl: mediaThumbUrl,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      mediaDuration: mediaDuration,
      caption: caption,
      media: mediaList,
      linkTitle: _asString(json['linkTitle']),
      linkDescription: _asString(json['linkDescription']),
      linkImageUrl: _asString(json['linkImageUrl']),
    );
  }
}