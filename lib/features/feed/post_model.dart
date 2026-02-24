class Post {
  final String id;
  final String text;
  final DateTime createdAt;
  final String authorHandle;

  // Media
  final String mediaType; // NONE | IMAGE | VIDEO | LINK
  final String? mediaUrl;
  final String? mediaThumbUrl;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? mediaDuration;
  final String? caption;

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
    this.mediaUrl,
    this.mediaThumbUrl,
    this.mediaWidth,
    this.mediaHeight,
    this.mediaDuration,
    this.caption,
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
    final s = v.toString();
    return s.trim().isEmpty ? null : s;
  }

  static int? _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return null;
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    final author = _asMap(json['author']);

    // Support both flat fields and nested media object (future-proof)
    final media = _asMap(json['media']);
    final mediaType = _asString(json['mediaType']) ??
        _asString(media?['type']) ??
        'NONE';

    final mediaUrl = _asString(json['mediaUrl']) ??
        _asString(media?['url']) ??
        _asString(media?['publicUrl']);

    final mediaThumbUrl = _asString(json['mediaThumbUrl']) ??
        _asString(media?['thumbUrl']) ??
        _asString(media?['thumbnailUrl']);

    final mediaWidth = _asInt(json['mediaWidth']) ?? _asInt(media?['width']);
    final mediaHeight = _asInt(json['mediaHeight']) ?? _asInt(media?['height']);
    final mediaDuration = _asInt(json['mediaDuration']) ?? _asInt(media?['duration']);

    return Post(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.parse((json['createdAt'] ?? '').toString()),
      authorHandle: (author?['handle'] as String?) ?? '',
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      mediaThumbUrl: mediaThumbUrl,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      mediaDuration: mediaDuration,
      caption: (json['caption'] as String?),
      linkTitle: (json['linkTitle'] as String?),
      linkDescription: (json['linkDescription'] as String?),
      linkImageUrl: (json['linkImageUrl'] as String?),
    );
  }
}