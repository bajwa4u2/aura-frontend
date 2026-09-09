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
    this.websiteUrl,
    this.publications = const <ProfilePublication>[],
    this.links = const <ProfileLink>[],
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

  /// The person's own site.
  ///
  /// The API has always sent it and this model never read it, so a member's
  /// website was invisible on their public profile — the same "stored but not
  /// shown" gap as publications, in the same payload.
  final String? websiteUrl;

  /// WORKS THE PERSON DECLARES, AND WHERE ELSE THEY ARE.
  ///
  /// The API has always sent both — `publicSelect` includes `links` and
  /// `publications` — and this model simply never read them, so the public
  /// profile could not show a person's own books however carefully they were
  /// stored. Founder-reported 2026-09-09: stored and invisible.
  ///
  /// A publication is the person's ASSERTION about an authored work, never a
  /// verified credential. See
  /// `aura-backend/docs/PROFILE_COLLECTIONS_CONTRACT.md`.
  final List<ProfilePublication> publications;
  final List<ProfileLink> links;

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
      websiteUrl: asNullableString(j['websiteUrl'] ?? j['website']),
      publications: ProfilePublication.listFrom(j['publications']),
      links: ProfileLink.listFrom(j['links']),
    );
  }
}

/// Read tolerantly, exactly as the canonical contract prescribes.
///
/// `url` is canonical; `link` and `href` are documented legacy aliases that
/// older payloads may still carry. Reading them costs nothing and refusing
/// them would blank a person's own work.
String? _pickString(Map<String, dynamic> j, List<String> names) {
  for (final name in names) {
    final value = (j[name] ?? '').toString().trim();
    if (value.isNotEmpty && value != 'null') return value;
  }
  return null;
}

List<Map<String, dynamic>> _asMaps(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => m.cast<String, dynamic>())
      .toList(growable: false);
}

/// AN AUTHORED WORK A PERSON DECLARES ON THEIR OWN PROFILE.
///
/// An assertion, not a verified credential and not an Aura Article. The title
/// is its identity; the URL is a destination, not the work itself.
class ProfilePublication {
  const ProfilePublication({
    required this.title,
    this.url,
    this.description,
    this.publisher,
    this.year,
    this.coverUrl,
  });

  final String title;
  final String? url;
  final String? description;
  final String? publisher;
  final int? year;

  /// The work's own cover, resolved from the destination's Open Graph image
  /// and served through Aura's proxy — never hotlinked, so a viewer is not
  /// exposed to the third-party host.
  ///
  /// ENRICHMENT ONLY. The title and description above are the person's
  /// assertion about their own work and are never replaced by what the page
  /// says about itself.
  final String? coverUrl;

  static List<ProfilePublication> listFrom(dynamic raw) {
    final out = <ProfilePublication>[];
    for (final item in _asMaps(raw)) {
      final title = _pickString(item, const ['title', 'name']);
      final url = _pickString(item, const ['url', 'link', 'href']);
      final description =
          _pickString(item, const ['description', 'summary', 'note']);
      // A row with nothing in it is a row nobody filled in.
      if (title == null && url == null && description == null) continue;
      out.add(
        ProfilePublication(
          title: title ?? 'Publication',
          url: url,
          description: description,
          publisher: _pickString(item, const ['publisher', 'venue']),
          year: item['year'] is num ? (item['year'] as num).toInt() : null,
          coverUrl: _pickString(item, const ['coverUrl', 'imageUrl']),
        ),
      );
    }
    return out;
  }
}

/// A general external destination. Deliberately NOT a publication: it carries
/// no description, publisher or year, and it is presented differently.
class ProfileLink {
  const ProfileLink({required this.url, this.label, this.iconUrl});

  final String url;
  final String? label;

  /// The destination's own mark — its favicon, proxied. A link needs the
  /// identity of where it goes, not a banner: giving it a publication's cover
  /// would erase the difference between an authored work and a bookmark.
  final String? iconUrl;

  static List<ProfileLink> listFrom(dynamic raw) {
    final out = <ProfileLink>[];
    for (final item in _asMaps(raw)) {
      final url = _pickString(item, const ['url', 'link', 'href']);
      if (url == null) continue;
      out.add(ProfileLink(
        url: url,
        label: _pickString(item, const ['label', 'title', 'name']),
        iconUrl: _pickString(item, const ['iconUrl', 'faviconUrl']),
      ));
    }
    return out;
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