class Profile {
  Profile({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    required this.followersCount,
    required this.followingCount,
    required this.followState,
  });

  final String id;
  final String handle;
  final String displayName;
  final String bio;
  final String avatarUrl;
  final int followersCount;
  final int followingCount;
  final String followState;

  bool get isFollowing => followState == 'following';

  factory Profile.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    final handle = (j['handle'] ?? '').toString().trim();
    final displayName = (j['displayName'] ?? '').toString().trim();

    return Profile(
      id: (j['id'] ?? '').toString(),
      handle: handle,
      displayName: displayName,
      bio: (j['bio'] ?? '').toString(),
      avatarUrl: (j['avatarUrl'] ?? '').toString(),
      followersCount: asInt(j['followersCount']),
      followingCount: asInt(j['followingCount']),
      followState: (j['followState'] ?? '').toString().trim(),
    );
  }
}

class ProfileListItem {
  ProfileListItem({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String handle;
  final String displayName;
  final String avatarUrl;

  factory ProfileListItem.fromJson(Map<String, dynamic> j) {
    return ProfileListItem(
      id: (j['id'] ?? '').toString(),
      handle: (j['handle'] ?? '').toString().trim(),
      displayName: (j['displayName'] ?? '').toString().trim(),
      avatarUrl: (j['avatarUrl'] ?? '').toString().trim(),
    );
  }
}