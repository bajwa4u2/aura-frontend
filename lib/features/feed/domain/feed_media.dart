/// Canonical media link surfaced through the unified feed and the
/// institution-post API. Mirrors the backend `FeedMediaDto` (and the
/// `media[]` array on `mapPost` in `institution-posts.service.ts`).
///
/// Empty list means "no canonical media link" — renderers should then
/// fall back to the legacy `mediaUrl` on the parent row.
///
/// `visibility` is a raw wire string (`PUBLIC` / `RESTRICTED` /
/// `PRIVATE`). Renderers branch on it:
///   * PUBLIC                  → render `url` directly via AuraAttachmentImage.
///   * RESTRICTED / PRIVATE    → render via AuraResolvableAttachmentImage,
///                                which fetches a fresh signed URL through
///                                MediaUrlResolver. The legacy `url` field
///                                still arrives in the wire payload but
///                                must NOT be rendered for non-public
///                                visibility.
class FeedMedia {
  const FeedMedia({
    required this.id,
    required this.mediaId,
    this.position = 0,
    this.caption,
    this.visibility = 'PUBLIC',
    this.mediaType,
    this.mimeType,
    this.width,
    this.height,
    this.duration,
    this.url,
    this.thumbUrl,
  });

  /// Stable join id (`InstitutionPostMedia.id`). Different from
  /// [mediaId], which is the canonical `Media.id`.
  final String id;

  /// Canonical Media id. Used as the cache key in AuraAttachmentImage
  /// and as the lookup key in MediaUrlResolver for RESTRICTED rows.
  final String mediaId;

  final int position;
  final String? caption;

  /// Wire string from backend MediaVisibility enum.
  final String visibility;

  /// 'IMAGE' | 'VIDEO' | 'AUDIO'. Wire shape may also include other
  /// strings if backend adds new types — renderers should treat unknown
  /// values as IMAGE.
  final String? mediaType;
  final String? mimeType;

  final int? width;
  final int? height;
  final int? duration;

  /// Permanent public URL when [visibility] is PUBLIC. For RESTRICTED /
  /// PRIVATE rows this is the legacy R2 URL — DO NOT render it
  /// directly; route through AuraResolvableAttachmentImage instead.
  final String? url;
  final String? thumbUrl;

  bool get isPublic => visibility.trim().toUpperCase() == 'PUBLIC';
  bool get isImage =>
      (mediaType ?? '').trim().toUpperCase() != 'VIDEO' &&
      (mediaType ?? '').trim().toUpperCase() != 'AUDIO';
  bool get isVideo => (mediaType ?? '').trim().toUpperCase() == 'VIDEO';
  bool get isAudio => (mediaType ?? '').trim().toUpperCase() == 'AUDIO';

  static FeedMedia? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final mediaId = (m['mediaId'] ?? m['id'] ?? '').toString().trim();
    if (mediaId.isEmpty) return null;
    final id = (m['id'] ?? mediaId).toString().trim();
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      final n = num.tryParse(v.toString());
      return n?.toInt();
    }

    return FeedMedia(
      id: id,
      mediaId: mediaId,
      position: toInt(m['position']) ?? 0,
      caption: m['caption']?.toString(),
      visibility: (m['visibility'] ?? 'PUBLIC').toString(),
      mediaType: m['mediaType']?.toString(),
      mimeType: m['mimeType']?.toString(),
      width: toInt(m['width']),
      height: toInt(m['height']),
      duration: toInt(m['duration']),
      url: m['url']?.toString(),
      thumbUrl: (m['thumbUrl'] ?? m['thumbnailUrl'])?.toString(),
    );
  }

  /// Tolerant list parser. Returns an empty list when [raw] is missing,
  /// not a List, or every entry fails to parse.
  static List<FeedMedia> listFromJson(dynamic raw) {
    if (raw is! List) return const <FeedMedia>[];
    final out = <FeedMedia>[];
    for (final entry in raw) {
      final m = tryFromJson(entry);
      if (m != null) out.add(m);
    }
    out.sort((a, b) => a.position.compareTo(b.position));
    return out;
  }
}
