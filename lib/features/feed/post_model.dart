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

  factory Post.fromJson(Map<String, dynamic> json) {
    final author = (json['author'] as Map<String, dynamic>?);

    return Post(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.parse((json['createdAt'] ?? '').toString()),
      authorHandle: (author?['handle'] as String?) ?? '',
      mediaType: (json['mediaType'] ?? 'NONE').toString(),
      mediaUrl: (json['mediaUrl'] as String?),
      mediaThumbUrl: (json['mediaThumbUrl'] as String?),
      mediaWidth: (json['mediaWidth'] as num?)?.toInt(),
      mediaHeight: (json['mediaHeight'] as num?)?.toInt(),
      mediaDuration: (json['mediaDuration'] as num?)?.toInt(),
      caption: (json['caption'] as String?),
      linkTitle: (json['linkTitle'] as String?),
      linkDescription: (json['linkDescription'] as String?),
      linkImageUrl: (json['linkImageUrl'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'author': <String, dynamic>{'handle': authorHandle},
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
}