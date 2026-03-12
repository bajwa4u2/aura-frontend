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
    final avatar =
        (rawAvatar == null || rawAvatar.trim().isEmpty) ? null : rawAvatar;

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

class PostMediaItem {
  const PostMediaItem({
    required this.id,
    required this.type,
    this.source,
    this.status,
    this.url,
    this.originalUrl,
    this.displayUrl,
    this.playbackUrl,
    this.thumbUrl,
    this.thumbnailUrl,
    this.caption,
    this.altText,
    this.transcript,
    this.width,
    this.height,
    this.duration,
    this.position,
    this.editDisclosure = false,
    this.mimeType,
    this.fileName,
    this.fileSizeBytes,
  });

  final String id;
  final String type;
  final String? source;
  final String? status;

  final String? url;
  final String? originalUrl;
  final String? displayUrl;
  final String? playbackUrl;
  final String? thumbUrl;
  final String? thumbnailUrl;

  final String? caption;
  final String? altText;
  final String? transcript;

  final int? width;
  final int? height;
  final int? duration;
  final int? position;

  final bool editDisclosure;

  final String? mimeType;
  final String? fileName;
  final int? fileSizeBytes;

  bool get isVideo => type.toUpperCase().contains('VIDEO');
  bool get isImage => type.toUpperCase().contains('IMAGE');
  bool get isAudio => type.toUpperCase().contains('AUDIO');

  String? get bestUrl {
    final candidates = [
      displayUrl,
      playbackUrl,
      url,
      originalUrl,
    ];
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c;
    }
    return null;
  }

  String? get bestThumbUrl {
    final candidates = [
      thumbnailUrl,
      thumbUrl,
      isVideo ? null : bestUrl,
    ];
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c;
    }
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

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = _asString(v)?.toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return false;
  }

  factory PostMediaItem.fromJson(Map<String, dynamic> j) {
    return PostMediaItem(
      id: (j['id'] ?? '').toString(),
      type: _asString(j['type']) ?? 'IMAGE',
      source: _asString(j['source']),
      status: _asString(j['status']),
      url: _asString(j['url']) ?? _asString(j['publicUrl']),
      originalUrl: _asString(j['originalUrl']),
      displayUrl: _asString(j['displayUrl']),
      playbackUrl: _asString(j['playbackUrl']),
      thumbUrl: _asString(j['thumbUrl']) ?? _asString(j['thumb']),
      thumbnailUrl: _asString(j['thumbnailUrl']),
      caption: _asString(j['caption']),
      altText: _asString(j['altText']),
      transcript: _asString(j['transcript']),
      width: _asInt(j['width']),
      height: _asInt(j['height']),
      duration: _asInt(j['duration']),
      position: _asInt(j['position']),
      editDisclosure: _asBool(j['editDisclosure']),
      mimeType: _asString(j['mimeType']),
      fileName: _asString(j['fileName']),
      fileSizeBytes: _asInt(j['fileSizeBytes']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'source': source,
        'status': status,
        'url': url,
        'originalUrl': originalUrl,
        'displayUrl': displayUrl,
        'playbackUrl': playbackUrl,
        'thumbUrl': thumbUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'altText': altText,
        'transcript': transcript,
        'width': width,
        'height': height,
        'duration': duration,
        'position': position,
        'editDisclosure': editDisclosure,
        'mimeType': mimeType,
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
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

    // New structured media contract.
    this.media = const <PostMediaItem>[],

    // Compatibility bridge fields.
    this.mediaType = 'NONE',
    this.mediaUrl,
    this.mediaThumbUrl,
    this.mediaWidth,
    this.mediaHeight,
    this.mediaDuration,
    this.caption,

    // Link preview
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

  // New structured media
  final List<PostMediaItem> media;

  // Compatibility bridge
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
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _asInt(dynamic v) {
    if (v is num) return v.toInt();
    final s = _asString(v);
    if (s == null) return null;
    return int.tryParse(s);
  }

  static List<PostMediaItem> _mediaListFromAny(dynamic mediaField) {
    if (mediaField is List) {
      return mediaField
          .whereType<Map>()
          .map((e) => PostMediaItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (mediaField is Map) {
      return [
        PostMediaItem.fromJson(Map<String, dynamic>.from(mediaField)),
      ];
    }

    return const <PostMediaItem>[];
  }

  static PostMediaItem? _pickPrimaryMediaItem(List<PostMediaItem> media) {
    if (media.isEmpty) return null;
    return media.first;
  }

  factory Post.fromJson(Map<String, dynamic> j) {
    final authorJson = j['author'];
    final a = (authorJson is Map)
        ? PostAuthor.fromJson(Map<String, dynamic>.from(authorJson))
        : null;

    final authorId = (j['authorId'] ?? a?.id ?? '').toString();

    final media = _mediaListFromAny(j['media']);
    final primaryMedia = _pickPrimaryMediaItem(media);

    final mediaType = _asString(j['mediaType']) ??
        primaryMedia?.type ??
        'NONE';

    final mediaUrl = _asString(j['mediaUrl']) ?? primaryMedia?.bestUrl;
    final mediaThumbUrl =
        _asString(j['mediaThumbUrl']) ?? primaryMedia?.bestThumbUrl;
    final mediaWidth = _asInt(j['mediaWidth']) ?? primaryMedia?.width;
    final mediaHeight = _asInt(j['mediaHeight']) ?? primaryMedia?.height;
    final mediaDuration =
        _asInt(j['mediaDuration']) ?? primaryMedia?.duration;
    final caption = _asString(j['caption']) ?? primaryMedia?.caption;

    return Post(
      id: (j['id'] ?? '').toString(),
      authorId: authorId,
      text: (j['text'] ?? '').toString(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      replyToPostId: _asString(j['replyToPostId']),
      repostOfPostId: _asString(j['repostOfPostId']),
      visibility: (j['visibility'] ?? 'public').toString(),
      author: a,

      media: media,

      mediaType: mediaType,
      mediaUrl: mediaUrl,
      mediaThumbUrl: mediaThumbUrl,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      mediaDuration: mediaDuration,
      caption: caption,

      linkTitle: _asString(j['linkTitle']),
      linkDescription:
          _asString(j['linkDescription']) ?? _asString(j['linkSubtitle']),
      linkImageUrl:
          _asString(j['linkImageUrl']) ?? _asString(j['linkThumbUrl']),
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

        'media': media.map((e) => e.toJson()).toList(),

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