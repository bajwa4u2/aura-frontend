class Profile {
  Profile({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.bio,
    this.title,
    required this.avatarUrl,
    this.coverUrl,
    this.location,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    this.isVerified = false,
    this.followState = 'none',
  });

  final String id;
  final String handle;
  final String displayName;
  final String? bio;

  /// Short professional headline shown under the display name.
  final String? title;
  final String? avatarUrl;
  final String? coverUrl;
  final String? location;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool isVerified;
  final String followState;

  factory Profile.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    bool asBool(dynamic v) {
      if (v is bool) return v;
      final text = (v ?? '').toString().trim().toLowerCase();
      return text == 'true' || text == '1' || text == 'yes';
    }

    String? asNullableString(dynamic v) {
      final text = (v ?? '').toString().trim();
      return text.isEmpty ? null : text;
    }

    final state = (j['followState'] ?? j['state'] ?? '').toString().trim();
    final following = j['isFollowing'] == true || state == 'following';

    return Profile(
      id: (j['id'] ?? '').toString().trim(),
      handle: (j['handle'] ?? '').toString().trim(),
      displayName: (j['displayName'] ?? '').toString().trim(),
      bio: asNullableString(j['bio']),
      title: asNullableString(j['title'] ?? j['headline']),
      avatarUrl: asNullableString(j['avatarUrl'] ?? j['avatar']),
      coverUrl: asNullableString(j['coverUrl'] ?? j['bannerUrl']),
      location: asNullableString(j['location']),
      followersCount: asInt(j['followersCount']),
      followingCount: asInt(j['followingCount']),
      isFollowing: following,
      isVerified: asBool(
        j['isVerified'] ??
            j['verified'] ??
            ((j['verificationStatus'] ?? '').toString().trim().toUpperCase() ==
                'VERIFIED'),
      ),
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
    String? asNullableString(dynamic v) {
      final text = (v ?? '').toString().trim();
      return text.isEmpty ? null : text;
    }

    return ProfileListItem(
      id: (j['id'] ?? '').toString().trim(),
      handle: (j['handle'] ?? '').toString().trim(),
      displayName: (j['displayName'] ?? '').toString().trim(),
      avatarUrl: asNullableString(j['avatarUrl'] ?? j['avatar']),
    );
  }
}