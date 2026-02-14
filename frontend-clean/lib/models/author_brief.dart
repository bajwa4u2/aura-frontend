class AuthorBrief {
  final String id;
  final String handle;
  final String displayName;
  final String? avatarUrl;

  const AuthorBrief({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
  });

  factory AuthorBrief.fromJson(Map<String, dynamic> json) {
    return AuthorBrief(
      id: (json['id'] ?? '').toString(),
      handle: (json['handle'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}
