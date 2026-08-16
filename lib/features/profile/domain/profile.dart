import '../../../core/trust/verification.dart';

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
    this.verification = const PersonVerification.none(),
    this.followState = 'none',
    this.accountStatus = 'ACTIVE',
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

  /// C2 — layered Person verification (canonical trust domain authority).
  /// A SET of governed classes, never a boolean: the legacy `isVerified`
  /// here parsed wire fields no profile endpoint ever sent, so the old
  /// person "Verified" badge was a dead generic claim path.
  final PersonVerification verification;
  final String followState;

  /// Account Lifecycle / Public Identity doctrine — 'ACTIVE' | 'DISABLED'
  /// | 'DELETED'. Direct profile resolution stays available for historical
  /// continuity even when non-active; this field is what lets the UI
  /// truthfully represent that instead of presenting every resolvable
  /// profile as fully active. Never carries a moderation reason.
  final String accountStatus;

  bool get isActive => accountStatus == 'ACTIVE';

  factory Profile.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
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
      verification: PersonVerification.fromJson(j['verification']),
      followState: state.isEmpty ? (following ? 'following' : 'none') : state,
      accountStatus: (j['accountStatus'] ?? 'ACTIVE').toString().trim().toUpperCase(),
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