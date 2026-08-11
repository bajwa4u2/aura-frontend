class Announcement {
  Announcement({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.excerpt,
    required this.bodyMarkdown,
    required this.pinned,
    required this.publishedAt,
    required this.media,
    this.linkUrl,
    this.linkTitle,
    this.linkDescription,
    this.linkImageUrl,
    this.linkSiteName,
    this.linkFaviconUrl,
  });

  final String id;
  final String slug;
  final String title;
  final String summary;
  final String excerpt;
  final String bodyMarkdown;
  final bool pinned;
  final DateTime? publishedAt;

  /// Backend-ready: [{ id, type, url, thumbUrl, width, height, duration, caption }]
  final List<Map<String, dynamic>> media;

  /// Compose Link Intelligence / OG Preview -- Phase 1 (Announcement
  /// extension). Same flat-field shape as Post/InstitutionPost/FeedItem --
  /// `linkUrl` is the author's exact typed URL, always present once a link
  /// was attached; the remaining fields only carry real values once the
  /// backend's preview resolved (status READY).
  final String? linkUrl;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImageUrl;
  final String? linkSiteName;
  final String? linkFaviconUrl;

  factory Announcement.fromJson(Map<String, dynamic> j) {
    final publishedRaw = j['publishedAt']?.toString();
    DateTime? published;
    if (publishedRaw != null && publishedRaw.isNotEmpty) {
      published = DateTime.tryParse(publishedRaw);
    }

    final rawMedia = j['media'];
    final media = <Map<String, dynamic>>[];
    if (rawMedia is List) {
      for (final it in rawMedia) {
        if (it is Map) media.add(Map<String, dynamic>.from(it.cast()));
      }
    }

    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return Announcement(
      id: (j['id'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      summary: (j['summary'] ?? '').toString(),
      excerpt: (j['excerpt'] ?? '').toString(),
      bodyMarkdown: (j['bodyMarkdown'] ?? j['bodyMd'] ?? '').toString(),
      pinned: (j['pinned'] == true),
      publishedAt: published,
      media: media,
      linkUrl: str(j['linkUrl']),
      linkTitle: str(j['linkTitle']),
      linkDescription: str(j['linkDescription']),
      linkImageUrl: str(j['linkImageUrl']),
      linkSiteName: str(j['linkSiteName']),
      linkFaviconUrl: str(j['linkFaviconUrl']),
    );
  }
}