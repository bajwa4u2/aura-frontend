import 'institution_post.dart';
import '../../../core/identity/person_identity_model.dart';

/// Unified feed entry for the institution Explore Public surface.
///
/// `/posts/public` returns a merged list of user posts and globally-
/// distributable institution posts. User posts and institution posts have
/// different shapes; this discriminator wraps both so one widget can render
/// either safely.
sealed class ExploreFeedItem {
  const ExploreFeedItem({required this.id, required this.publishedAt});

  /// Stable id for the underlying entity. Used by ListView keys and dedupe.
  final String id;

  /// Published-at timestamp used for sorting + display. Falls back to
  /// createdAt when the post isn't yet published.
  final DateTime? publishedAt;

  /// Parses one item from the merged `/posts/public` response. Returns null
  /// when the row cannot be discriminated (unknown `kind`).
  static ExploreFeedItem? fromJson(Map<String, dynamic> json) {
    final kind = (json['kind'] ?? 'POST').toString().trim().toUpperCase();
    if (kind == 'INSTITUTION_POST') {
      return ExploreInstitutionPost.fromJson(json);
    }
    return ExploreUserPost.fromJson(json);
  }
}

/// User-authored post returned by the global feed endpoint.
class ExploreUserPost extends ExploreFeedItem {
  const ExploreUserPost({
    required super.id,
    required super.publishedAt,
    required this.text,
    required this.author,
    this.media = const <ExploreMediaPreview>[],
  });

  final String text;

  /// The person who published it. Explore shows institution-authored posts
  /// through a different type, so this one is always a person.
  final AuraPersonIdentity author;

  String get authorDisplayName => author.displayName;
  String get authorHandle => author.handle;
  String? get authorAvatarUrl => author.avatarUrl;
  final List<ExploreMediaPreview> media;

  factory ExploreUserPost.fromJson(Map<String, dynamic> json) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = json[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final str = raw.toString().trim();
      if (str.isEmpty) return null;
      return DateTime.tryParse(str);
    }

    final author = json['author'];
    final authorMap = author is Map ? Map<String, dynamic>.from(author) : null;

    final mediaRaw = json['media'];
    final media = mediaRaw is List
        ? mediaRaw
            .whereType<Map>()
            .map((m) => ExploreMediaPreview.fromJson(
                  Map<String, dynamic>.from(m),
                ))
            .where((m) => m.url.isNotEmpty)
            .toList()
        : <ExploreMediaPreview>[];

    return ExploreUserPost(
      id: s(['id']),
      publishedAt: readDate(json['publishedAt'] ?? json['createdAt']),
      text: s(['text', 'body']),
      author: AuraPersonIdentity.fromJson(authorMap),
      media: media,
    );
  }
}

/// Institution-authored post returned by the global feed endpoint. Carries a
/// nested institution summary so the card can render the institution as the
/// post author.
class ExploreInstitutionPost extends ExploreFeedItem {
  const ExploreInstitutionPost({
    required super.id,
    required super.publishedAt,
    required this.title,
    required this.body,
    required this.institutionId,
    required this.institutionName,
    required this.institutionSlug,
    this.institutionLogoUrl,
    this.mediaUrl,
    required this.visibility,
  });

  final String title;
  final String body;
  final String institutionId;
  final String institutionName;
  final String institutionSlug;
  final String? institutionLogoUrl;
  final String? mediaUrl;
  final InstitutionPostVisibility visibility;

  factory ExploreInstitutionPost.fromJson(Map<String, dynamic> json) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = json[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    String? opt(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return null;
    }

    DateTime? readDate(dynamic raw) {
      if (raw == null) return null;
      final str = raw.toString().trim();
      if (str.isEmpty) return null;
      return DateTime.tryParse(str);
    }

    final inst = json['institution'] is Map
        ? Map<String, dynamic>.from(json['institution'] as Map)
        : <String, dynamic>{};

    return ExploreInstitutionPost(
      id: s(['id']),
      publishedAt: readDate(json['publishedAt'] ?? json['createdAt']),
      title: s(['title']),
      body: s(['body']),
      institutionId: s(['institutionId']),
      institutionName: opt(inst, ['name', 'displayName']) ?? '',
      institutionSlug: opt(inst, ['slug', 'handle']) ?? '',
      institutionLogoUrl: opt(inst, ['logoUrl', 'avatarUrl']),
      mediaUrl: json['mediaUrl']?.toString().trim().isNotEmpty == true
          ? json['mediaUrl'].toString().trim()
          : null,
      visibility: InstitutionPostVisibilityX.fromWire(json['visibility']),
    );
  }
}

class ExploreMediaPreview {
  const ExploreMediaPreview({
    required this.url,
    this.thumbUrl,
    this.type,
  });

  final String url;
  final String? thumbUrl;
  final String? type;

  bool get isVideo {
    final t = (type ?? '').toUpperCase();
    return t == 'VIDEO';
  }

  factory ExploreMediaPreview.fromJson(Map<String, dynamic> json) {
    String pickStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    return ExploreMediaPreview(
      url: pickStr(['url', 'mediaUrl', 'displayUrl', 'sourceUrl']),
      thumbUrl: pickStr(['thumbUrl', 'thumbnailUrl', 'previewUrl']).isEmpty
          ? null
          : pickStr(['thumbUrl', 'thumbnailUrl', 'previewUrl']),
      type: pickStr(['type', 'kind']).isEmpty
          ? null
          : pickStr(['type', 'kind']),
    );
  }
}

class ExploreFeedPage {
  const ExploreFeedPage({required this.items, this.nextCursor});

  final List<ExploreFeedItem> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}
