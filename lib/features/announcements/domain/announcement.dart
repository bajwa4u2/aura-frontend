class Announcement {
  Announcement({
    required this.id,
    required this.slug,
    required this.title,
    required this.body,
    required this.pinned,
    required this.publishedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String body;
  final bool pinned;
  final DateTime? publishedAt;

  factory Announcement.fromJson(Map<String, dynamic> j) {
    final publishedRaw = j['publishedAt']?.toString();
    DateTime? published;
    if (publishedRaw != null && publishedRaw.isNotEmpty) {
      published = DateTime.tryParse(publishedRaw);
    }
    return Announcement(
      id: (j['id'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? j['content'] ?? '').toString(),
      pinned: (j['pinned'] == true),
      publishedAt: published,
    );
  }
}
