import '../../../core/trust/verification.dart';
import '../../../core/identity/person_identity_model.dart';

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

    // F116 case 2 — the person half is read canonically; everything below is
    // profile CONTENT and stays this model's own.
    final person = AuraPersonIdentity.fromJson(j);

    return Profile(
      id: person.userId,
      handle: person.handle,
      displayName: person.displayName,
      bio: asNullableString(j['bio']),
      title: asNullableString(j['title'] ?? j['headline']),
      avatarUrl: person.avatarUrl ?? asNullableString(j['avatar']),
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

/// F116 case 1 — a RENAMED PERSON REFERENCE SUBSET. The type survives as a
/// name its callers already use, but it no longer interprets identity: it
/// composes the canonical person and forwards. `avatar` is a legacy alias
/// this endpoint alone still sends, adapted here at the boundary rather than
/// widening the canonical reader.
class ProfileListItem {
  ProfileListItem({required this.person, String? legacyAvatarUrl})
      : _legacyAvatarUrl = legacyAvatarUrl;

  final AuraPersonIdentity person;
  final String? _legacyAvatarUrl;

  String get id => person.userId;
  String get handle => person.handle;
  String get displayName => person.displayName;
  String? get avatarUrl => person.avatarUrl ?? _legacyAvatarUrl;

  factory ProfileListItem.fromJson(Map<String, dynamic> j) {
    final legacy = (j['avatar'] ?? '').toString().trim();
    return ProfileListItem(
      person: AuraPersonIdentity.fromJson(j),
      legacyAvatarUrl: legacy.isEmpty ? null : legacy,
    );
  }
}