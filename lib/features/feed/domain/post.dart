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
    final rawAvatar = _readString(j['avatarUrl']);

    return PostAuthor(
      id: _readString(j['id']) ?? '',
      handle: _readString(j['handle']) ?? '',
      displayName: _readString(j['displayName']) ?? _readString(j['name']) ?? '',
      avatarUrl: rawAvatar,
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
    final candidates = [displayUrl, playbackUrl, url, originalUrl];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) return candidate;
    }
    return null;
  }

  String? get bestThumbUrl {
    final candidates = [thumbnailUrl, thumbUrl, isVideo ? null : bestUrl];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) return candidate;
    }
    return null;
  }

  factory PostMediaItem.fromJson(Map<String, dynamic> j) {
    return PostMediaItem(
      id: _readString(j['id']) ?? '',
      type: _readString(j['type']) ?? 'IMAGE',
      source: _readString(j['source']),
      status: _readString(j['status']),
      url: _readString(j['url']) ?? _readString(j['publicUrl']),
      originalUrl: _readString(j['originalUrl']),
      displayUrl: _readString(j['displayUrl']),
      playbackUrl: _readString(j['playbackUrl']),
      thumbUrl: _readString(j['thumbUrl']) ?? _readString(j['thumb']),
      thumbnailUrl: _readString(j['thumbnailUrl']),
      caption: _readString(j['caption']),
      altText: _readString(j['altText']),
      transcript: _readString(j['transcript']),
      width: _readInt(j['width']),
      height: _readInt(j['height']),
      duration: _readInt(j['duration']),
      position: _readInt(j['position']),
      editDisclosure: _readBool(j['editDisclosure']),
      mimeType: _readString(j['mimeType']),
      fileName: _readString(j['fileName']),
      fileSizeBytes: _readInt(j['fileSizeBytes']),
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

class PostTranslation {
  const PostTranslation({
    required this.language,
    required this.text,
    this.provider,
    this.status,
  });

  final String language;
  final String text;
  final String? provider;
  final String? status;

  bool get isUsable => language.trim().isNotEmpty && text.trim().isNotEmpty;

  factory PostTranslation.fromJson(Map<String, dynamic> json) {
    return PostTranslation(
      language: _readString(
            json['language'] ?? json['targetLanguage'] ?? json['locale'],
          ) ??
          '',
      text: _readString(
            json['text'] ?? json['translatedText'] ?? json['content'],
          ) ??
          '',
      provider: _readString(json['provider']),
      status: _readString(json['status']),
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'text': text,
        'provider': provider,
        'status': status,
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
    this.media = const <PostMediaItem>[],
    this.mediaType = 'NONE',
    this.mediaUrl,
    this.mediaThumbUrl,
    this.mediaWidth,
    this.mediaHeight,
    this.mediaDuration,
    this.caption,
    this.linkTitle,
    this.linkDescription,
    this.linkImageUrl,
    this.originalLanguage,
    this.translatedLanguage,
    this.translatedText,
    this.translationStatus,
    this.availableTranslations = const <PostTranslation>[],
  });

  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;

  final String? replyToPostId;
  final String? repostOfPostId;
  final String visibility;

  final PostAuthor? author;
  final List<PostMediaItem> media;

  final String mediaType;
  final String? mediaUrl;
  final String? mediaThumbUrl;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? mediaDuration;
  final String? caption;

  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;

  final String? originalLanguage;
  final String? translatedLanguage;
  final String? translatedText;
  final String? translationStatus;
  final List<PostTranslation> availableTranslations;

  bool get hasTranslatedText =>
      translatedText != null && translatedText!.trim().isNotEmpty;

  String displayText({String? preferredLanguage}) {
    final preferred = preferredLanguage?.trim().toLowerCase();
    if (preferred != null && preferred.isNotEmpty) {
      for (final entry in availableTranslations) {
        if (entry.language.trim().toLowerCase() == preferred &&
            entry.text.trim().isNotEmpty) {
          return entry.text;
        }
      }
    }

    if (hasTranslatedText) return translatedText!.trim();
    return text;
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? text,
    DateTime? createdAt,
    String? replyToPostId,
    String? repostOfPostId,
    String? visibility,
    PostAuthor? author,
    List<PostMediaItem>? media,
    String? mediaType,
    String? mediaUrl,
    String? mediaThumbUrl,
    int? mediaWidth,
    int? mediaHeight,
    int? mediaDuration,
    String? caption,
    String? linkTitle,
    String? linkDescription,
    String? linkImageUrl,
    String? originalLanguage,
    String? translatedLanguage,
    String? translatedText,
    String? translationStatus,
    List<PostTranslation>? availableTranslations,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      replyToPostId: replyToPostId ?? this.replyToPostId,
      repostOfPostId: repostOfPostId ?? this.repostOfPostId,
      visibility: visibility ?? this.visibility,
      author: author ?? this.author,
      media: media ?? this.media,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaThumbUrl: mediaThumbUrl ?? this.mediaThumbUrl,
      mediaWidth: mediaWidth ?? this.mediaWidth,
      mediaHeight: mediaHeight ?? this.mediaHeight,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      caption: caption ?? this.caption,
      linkTitle: linkTitle ?? this.linkTitle,
      linkDescription: linkDescription ?? this.linkDescription,
      linkImageUrl: linkImageUrl ?? this.linkImageUrl,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      translatedLanguage: translatedLanguage ?? this.translatedLanguage,
      translatedText: translatedText ?? this.translatedText,
      translationStatus: translationStatus ?? this.translationStatus,
      availableTranslations:
          availableTranslations ?? this.availableTranslations,
    );
  }

  factory Post.fromJson(Map<String, dynamic> j) {
    final authorJson = _readMap(j['author']);
    final author = authorJson != null ? PostAuthor.fromJson(authorJson) : null;

    final authorId = _readString(j['authorId']) ?? author?.id ?? '';

    final media = _readMediaList(j['media']);
    final primaryMedia = media.isNotEmpty ? media.first : null;

    final translations = _readTranslations(
      j['translations'] ?? j['availableTranslations'],
    );

    final translatedText = _readString(
      j['translatedText'] ?? j['translationText'] ?? j['viewerText'],
    );

    final translatedLanguage = _readString(
      j['translatedLanguage'] ?? j['targetLanguage'] ?? j['viewerLanguage'],
    );

    final mediaType =
        _readString(j['mediaType']) ?? primaryMedia?.type ?? 'NONE';

    return Post(
      id: _readString(j['id']) ?? '',
      authorId: authorId,
      text: _readString(j['text']) ?? '',
      createdAt: DateTime.tryParse(_readString(j['createdAt']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      replyToPostId: _readString(j['replyToPostId']),
      repostOfPostId: _readString(j['repostOfPostId']),
      visibility: _readString(j['visibility']) ?? 'public',
      author: author,
      media: media,
      mediaType: mediaType,
      mediaUrl: _readString(j['mediaUrl']) ?? primaryMedia?.bestUrl,
      mediaThumbUrl:
          _readString(j['mediaThumbUrl']) ?? primaryMedia?.bestThumbUrl,
      mediaWidth: _readInt(j['mediaWidth']) ?? primaryMedia?.width,
      mediaHeight: _readInt(j['mediaHeight']) ?? primaryMedia?.height,
      mediaDuration: _readInt(j['mediaDuration']) ?? primaryMedia?.duration,
      caption: _readString(j['caption']) ?? primaryMedia?.caption,
      linkTitle: _readString(j['linkTitle']) ?? _readString(j['title']),
      linkDescription: _readString(
            j['linkDescription'] ?? j['linkSubtitle'] ?? j['description'],
          ) ??
          _readString(j['subtitle']),
      linkImageUrl:
          _readString(j['linkImageUrl']) ?? _readString(j['linkThumbUrl']),
      originalLanguage: _readString(
        j['originalLanguage'] ?? j['sourceLanguage'] ?? j['language'],
      ),
      translatedLanguage: translatedLanguage,
      translatedText: translatedText,
      translationStatus: _readString(j['translationStatus']),
      availableTranslations: translations,
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
        'originalLanguage': originalLanguage,
        'translatedLanguage': translatedLanguage,
        'translatedText': translatedText,
        'translationStatus': translationStatus,
        'translations': availableTranslations.map((e) => e.toJson()).toList(),
      };
}

Map<String, dynamic>? _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _readString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = _readString(value);
  if (text == null) return null;
  return int.tryParse(text);
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final text = _readString(value)?.toLowerCase();
  return text == 'true' || text == '1';
}

List<PostMediaItem> _readMediaList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => PostMediaItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  if (value is Map) {
    return [PostMediaItem.fromJson(Map<String, dynamic>.from(value))];
  }

  return const <PostMediaItem>[];
}

List<PostTranslation> _readTranslations(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => PostTranslation.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.isUsable)
        .toList();
  }

  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final items = <PostTranslation>[];
    map.forEach((key, rawValue) {
      if (rawValue is Map) {
        final merged = <String, dynamic>{'language': key, ...Map<String, dynamic>.from(rawValue)};
        final item = PostTranslation.fromJson(merged);
        if (item.isUsable) items.add(item);
      } else {
        final text = _readString(rawValue);
        if (text != null && text.isNotEmpty) {
          items.add(PostTranslation(language: key, text: text));
        }
      }
    });
    return items;
  }

  return const <PostTranslation>[];
}
