class Profile {
  const Profile({
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
  final String bio;
  final String? avatarUrl;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;

  factory Profile.fromJson(Map<String, dynamic> j) {
    return Profile(
      id: (j['id'] ?? '') as String,
      handle: (j['handle'] ?? '') as String,
      displayName: (j['displayName'] ?? j['name'] ?? '') as String,
      bio: (j['bio'] ?? '') as String,
      avatarUrl: _asNullableString(j['avatarUrl']),
      followersCount: _asInt(j['followersCount'] ?? j['followers'] ?? 0),
      followingCount: _asInt(j['followingCount'] ?? j['following'] ?? 0),
      isFollowing: j['isFollowing'] == true,
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String? _asNullableString(dynamic v) {
    final s = v?.toString();
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
