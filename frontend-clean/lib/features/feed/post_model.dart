class Post {
  final String id;
  final String text;
  final DateTime createdAt;
  final String authorHandle;

  Post({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.authorHandle,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final author = (json['author'] as Map<String, dynamic>?);
    return Post(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      authorHandle: (author?['handle'] as String?) ?? '',
    );
  }
}
