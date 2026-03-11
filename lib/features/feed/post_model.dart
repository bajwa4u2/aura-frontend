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

    final handle = _asStringReq(
      m['handle'] ?? m['username'] ?? m['authorHandle'],
    );

    final displayName = _asStringReq(
      m['displayName'] ?? m['name'] ?? handle,
    );

    return PostAuthor(
      id: _asStringReq(m['id']),
      handle: handle,
      displayName: displayName,
      avatarUrl: _asStringOpt(
        m['avatarUrl'] ?? m['avatar'] ?? m['imageUrl'],
      ),
    );
  }
}

class PostMedia {
  final String id;
  final String type; // IMAGE | VIDEO | SVG | OTHER
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

    final type = _asStringReq(
      m['type'] ?? m['kind'] ?? m['mediaType'],
      fallback: 'OTHER',
    );

    final url = _asStringReq(
      m['url'] ?? m['publicUrl'] ?? m['src'],
    );

    return PostMedia(
      id: _asStringReq(m['id']),
      type: type,
      url: url,
      thumbUrl: _asStringOpt(
        m['thumbUrl'] ?? m['thumbnailUrl'] ?? m['thumb'],
      ),
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

  final PostAuthor? author;

  // Back-compat
  final String authorHandle;

  final String? status; // DRAFT | PUBLISHED
  final String? visibility; // PUBLIC | FOLLOWERS | PRIVATE
  final String? replyToPostId;
  final String? repostOfPostId;

  // Flat media fields for older UI
  final String mediaType; // NONE | IMAGE | VIDEO | LINK | OTHER
  final String? mediaUrl;
  final String? mediaThumbUrl;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? mediaDuration;
  final String? caption;

  final List<PostMedia> media;

  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;

  const Post({
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

  static String _asStringReq(dynamic v, {String fallback = ''}) {
    final s = _asString(v);
    return s ?? fallback;
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
    if (s == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.tryParse(s) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static List<PostMedia> _parseMediaList(dynamic v) {
    if (v is List) {
      return v
          .map(PostMedia.fromJson)
          .where((m) => m.url.trim().isNotEmpty)
          .toList();
    }

    if (v is Map) {
      final one = PostMedia.fromJson(v);
      if (one.url.trim().isNotEmpty) return <PostMedia>[one];
    }

    return const <PostMedia>[];
  }

  static String _deriveMediaTypeFromPrimary(PostMedia? m) {
    if (m == null) return 'NONE';

    final t = m.type.toUpperCase();

    if (t.contains('VIDEO')) return 'VIDEO';
    if (t.contains('IMAGE') || t.contains('SVG')) return 'IMAGE';
    if (t.contains('LINK')) return 'LINK';

    final url = m.url.toLowerCase();
    if (url.endsWith('.mp4') || url.endsWith('.mov') || url.endsWith('.webm')) {
      return 'VIDEO';
    }
    if (url.endsWith('.png') ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.webp') ||
        url.endsWith('.gif') ||
        url.endsWith('.svg')) {
      return 'IMAGE';
    }

    return 'OTHER';
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    final authorMap = _asMap(json['author']);
    final author = authorMap != null ? PostAuthor.fromJson(authorMap) : null;

    final mediaList = _parseMediaList(
      json['media'] ?? json['mediaItems'],
    );
    final primary = mediaList.isNotEmpty ? mediaList.first : null;

    final flatMediaType = _asString(json['mediaType']);
    final derivedType = _deriveMediaTypeFromPrimary(primary);

    final mediaType = (() {
      final raw = (flatMediaType ?? derivedType).trim();
      return raw.isEmpty ? 'NONE' : raw.toUpperCase();
    })();

    final mediaUrl = _asString(json['mediaUrl']) ?? _asString(primary?.url);
    final mediaThumbUrl =
        _asString(json['mediaThumbUrl']) ?? _asString(primary?.thumbUrl);

    final mediaWidth = _asInt(json['mediaWidth']) ?? _asInt(primary?.width);
    final mediaHeight = _asInt(json['mediaHeight']) ?? _asInt(primary?.height);
    final mediaDuration =
        _asInt(json['mediaDuration']) ?? _asInt(primary?.duration);

    final caption = _asString(json['caption']) ?? _asString(primary?.caption);

    final handle = author?.handle ??
        _asString(authorMap?['handle']) ??
        _asString(json['authorHandle']) ??
        '';
    final authorHandle = handle;

    return Post(
      id: _asStringReq(json['id']),
      text: _asStringReq(json['text']),
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
      linkTitle: _asString(json['linkTitle'] ?? json['title']),
      linkDescription: _asString(
        json['linkDescription'] ?? json['linkSubtitle'] ?? json['description'],
      ),
      linkImageUrl: _asString(
        json['linkImageUrl'] ?? json['linkThumbUrl'] ?? json['image'],
      ),
    );
  }
}