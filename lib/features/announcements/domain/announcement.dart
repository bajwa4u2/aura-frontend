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
    );
  }
}