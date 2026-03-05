class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String handle;
  final String displayName;
  final String? avatarUrl;

  factory PostAuthor.fromJson(Map<String, dynamic> j) {
    final rawAvatar = j['avatarUrl'] as String?;
    final avatar = (rawAvatar == null || rawAvatar.trim().isEmpty) ? null : rawAvatar;

    return PostAuthor(
      id: (j['id'] ?? '').toString(),
      handle: (j['handle'] ?? '').toString(),
      displayName: (j['displayName'] ?? j['name'] ?? '').toString(),
      avatarUrl: avatar,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'handle': handle,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };
}

class Post {
  Post({
    required this.id,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.replyToPostId,
    this.repostOfPostId,
    this.visibility = 'public',
    this.author,

    // Media
    this.mediaType = 'NONE', // NONE | IMAGE | VIDEO | LINK
    this.mediaUrl,
    this.mediaThumbUrl,
    this.mediaWidth,
    this.mediaHeight,
    this.mediaDuration,
    this.caption,

    // Link preview (optional)
    this.linkTitle,
    this.linkDescription,
    this.linkImageUrl,
  });

  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;

  final String? replyToPostId;
  final String? repostOfPostId;
  final String visibility;

  final PostAuthor? author;

  // Media
  final String mediaType;
  final String? mediaUrl;
  final String? mediaThumbUrl;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? mediaDuration;
  final String? caption;

  // Link preview
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;

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
    final s = _asString(v);
    if (s == null) return null;
    return int.tryParse(s);
  }

  static Map<String, dynamic>? _pickPrimaryMediaMap(dynamic mediaField) {
    // New backend shape: media is List<Media>
    if (mediaField is List && mediaField.isNotEmpty) {
      final first = mediaField.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    // Legacy shape: media is object
    if (mediaField is Map) return Map<String, dynamic>.from(mediaField);
    return null;
  }

  factory Post.fromJson(Map<String, dynamic> j) {
    final authorJson = j['author'];
    final a = (authorJson is Map) ? PostAuthor.fromJson(Map<String, dynamic>.from(authorJson)) : null;

    final authorId = (j['authorId'] ?? a?.id ?? '').toString();

    // Support:
    // - flat media fields
    // - legacy media object
    // - NEW media array (primary = first)
    final primaryMedia = _pickPrimaryMediaMap(j['media']);

    final mediaType = _asString(j['mediaType']) ??
        _asString(primaryMedia?['type']) ??
        _asString(primaryMedia?['mediaType']) ??
        'NONE';

    final mediaUrl = _asString(j['mediaUrl']) ??
        _asString(primaryMedia?['url']) ??
        _asString(primaryMedia?['publicUrl']);

    final mediaThumbUrl = _asString(j['mediaThumbUrl']) ??
        _asString(primaryMedia?['thumbUrl']) ??
        _asString(primaryMedia?['thumbnailUrl']) ??
        _asString(primaryMedia?['thumb']);

    final mediaWidth = _asInt(j['mediaWidth']) ?? _asInt(primaryMedia?['width']);
    final mediaHeight = _asInt(j['mediaHeight']) ?? _asInt(primaryMedia?['height']);
    final mediaDuration = _asInt(j['mediaDuration']) ?? _asInt(primaryMedia?['duration']);

    return Post(
      id: (j['id'] ?? '').toString(),
      authorId: authorId,
      text: (j['text'] ?? '').toString(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      replyToPostId: j['replyToPostId'] as String?,
      repostOfPostId: j['repostOfPostId'] as String?,
      visibility: (j['visibility'] ?? 'public').toString(),
      author: a,

      mediaType: mediaType,
      mediaUrl: mediaUrl,
      mediaThumbUrl: mediaThumbUrl,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      mediaDuration: mediaDuration,
      caption: (j['caption'] as String?) ?? _asString(primaryMedia?['caption']),

      linkTitle: j['linkTitle'] as String?,
      linkDescription: j['linkDescription'] as String?,
      linkImageUrl: j['linkImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'replyToPostId': replyToPostId,
        'repostOfPostId': repostOfPostId,
        'visibility': visibility,
        'author': author?.toJson(),
        'mediaType': mediaType,
        'mediaUrl': mediaUrl,
        'mediaThumbUrl': mediaThumbUrl,
        'mediaWidth': mediaWidth,
        'mediaHeight': mediaHeight,
        'mediaDuration': mediaDuration,
        'caption': caption,
        'linkTitle': linkTitle,
        'linkDescription': linkDescription,
        'linkImageUrl': linkImageUrl,
      };
}