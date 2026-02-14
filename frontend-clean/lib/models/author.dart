class Author {
  final String id;
  final String name;
  final String handle;
  final String bio;
  final String? avatarUrl;

  const Author({
    required this.id,
    required this.name,
    required this.handle,
    required this.bio,
    this.avatarUrl,
  });

  Author copyWith({
    String? name,
    String? handle,
    String? bio,
    String? avatarUrl,
  }) {
    return Author(
      id: id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl,
    );
  }
}
