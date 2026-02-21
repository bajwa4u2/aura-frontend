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
    return PostAuthor(
      id: (j['id'] ?? '') as String,
      handle: (j['handle'] ?? '') as String,
      displayName: (j['displayName'] ?? j['name'] ?? '') as String,
      avatarUrl: (j['avatarUrl'] as String?)?.trim().isEmpty == true ? null : (j['avatarUrl'] as String?),
    );
  }
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
  });

  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;

  final String? replyToPostId;
  final String? repostOfPostId;
  final String visibility;

  /// Optional hydrated author object (used by UI)
  final PostAuthor? author;

  factory Post.fromJson(Map<String, dynamic> j) {
    final authorJson = j['author'];
    final a = (authorJson is Map) ? PostAuthor.fromJson(Map<String, dynamic>.from(authorJson)) : null;

    final authorId = (j['authorId'] ?? a?.id ?? '') as String;

    return Post(
      id: (j['id'] ?? '') as String,
      authorId: authorId,
      text: (j['text'] ?? '') as String,
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      replyToPostId: j['replyToPostId'] as String?,
      repostOfPostId: j['repostOfPostId'] as String?,
      visibility: (j['visibility'] ?? 'public') as String,
      author: a,
    );
  }
}
