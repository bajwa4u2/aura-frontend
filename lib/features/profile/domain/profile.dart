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
    this.followState = 'none',
  });

  final String id;
  final String handle;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final String followState;

  factory Profile.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    final state = (j['followState'] ?? j['state'] ?? '').toString().trim();
    final following = j['isFollowing'] == true || state == 'following';

    return Profile(
      id: (j['id'] ?? '').toString(),
      handle: (j['handle'] ?? '').toString(),
      displayName: (j['displayName'] ?? '').toString(),
      bio: j['bio'] as String?,
      avatarUrl: j['avatarUrl'] as String?,
      followersCount: asInt(j['followersCount']),
      followingCount: asInt(j['followingCount']),
      isFollowing: following,
      followState: state.isEmpty ? (following ? 'following' : 'none') : state,
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
  final String? avatarUrl;

  factory ProfileListItem.fromJson(Map<String, dynamic> j) {
    return ProfileListItem(
      id: (j['id'] ?? '').toString(),
      handle: (j['handle'] ?? '').toString().trim(),
      displayName: (j['displayName'] ?? '').toString().trim(),
      avatarUrl: j['avatarUrl'] as String?,
    );
  }
}