class Announcement {
  Announcement({
    required this.id,
    required this.slug,
    required this.title,
    required this.body,
    required this.pinned,
    required this.publishedAt,
    this.media = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String body;
  final bool pinned;
  final DateTime? publishedAt;

  // NEW
  final List<AnnouncementMedia> media;

  factory Announcement.fromJson(Map<String, dynamic> j) {
    final publishedRaw = j['publishedAt']?.toString();
    DateTime? published;
    if (publishedRaw != null && publishedRaw.isNotEmpty) {
      published = DateTime.tryParse(publishedRaw);
    }

    final mediaList = (j['media'] as List?)
            ?.map((m) => AnnouncementMedia.fromJson(m))
            .toList() ??
        const <AnnouncementMedia>[];

    return Announcement(
      id: (j['id'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? j['content'] ?? '').toString(),
      pinned: (j['pinned'] == true),
      publishedAt: published,
      media: mediaList,
    );
  }
}

class AnnouncementMedia {
  AnnouncementMedia({
    required this.url,
    required this.type,
    this.thumbUrl,
    this.width,
    this.height,
    this.duration,
  });

  final String url;
  final String type;
  final String? thumbUrl;
  final int? width;
  final int? height;
  final int? duration;

  factory AnnouncementMedia.fromJson(Map<String, dynamic> j) {
    return AnnouncementMedia(
      url: (j['url'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      thumbUrl: j['thumbUrl']?.toString(),
      width: j['width'] is int ? j['width'] : null,
      height: j['height'] is int ? j['height'] : null,
      duration: j['duration'] is int ? j['duration'] : null,
    );
  }
}