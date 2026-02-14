class Profile {
  Profile({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
  });

  final String id;
  final String handle;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;

  factory Profile.fromJson(Map<String, dynamic> j) {
    return Profile(
      id: j['id'] as String,
      handle: j['handle'] as String,
      displayName: j['displayName'] as String,
      bio: j['bio'] as String?,
      avatarUrl: j['avatarUrl'] as String?,
      followersCount: (j['followersCount'] ?? 0) as int,
      followingCount: (j['followingCount'] ?? 0) as int,
      isFollowing: (j['isFollowing'] ?? false) as bool,
    );
  }
}
