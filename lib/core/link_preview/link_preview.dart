/// Compose Link Intelligence / OG Preview -- Phase 1.
///
/// Canonical client-side model for a resolved link preview, mirroring the
/// backend's `LinkPreviewResult` shape exactly (`POST /link-previews/resolve`).
/// One model, consumed identically by member post compose and institution
/// post compose -- neither surface defines its own shape.
library;

class LinkPreview {
  const LinkPreview({
    required this.eligible,
    required this.internal,
    required this.sourceUrl,
    this.canonicalUrl,
    this.linkPreviewId,
    required this.status,
    this.title,
    this.description,
    this.siteName,
    this.imageUrl,
    this.faviconUrl,
  });

  /// False when the pasted text wasn't a resolvable http(s) URL at all --
  /// callers should not render anything (not even a plain-link chip).
  final bool eligible;

  /// True for a URL pointing back into Aura itself -- never fetched, never
  /// rendered as a generic OG card (preserves deep-link semantics).
  final bool internal;

  final String sourceUrl;
  final String? canonicalUrl;
  final String? linkPreviewId;

  /// One of: PENDING, READY, UNAVAILABLE, UNSAFE, INTERNAL, INELIGIBLE.
  final String status;

  final String? title;
  final String? description;
  final String? siteName;
  final String? imageUrl;
  final String? faviconUrl;

  /// True only when there is real OG metadata to render as a card.
  /// Everything else (including a successfully-attached but
  /// metadata-less link) degrades to a plain link, never a broken card.
  bool get hasRichMetadata => status == 'READY' && (title != null || imageUrl != null);

  /// True when the link should still be attached/submitted even though
  /// there's no rich card to show for it (internal link, or fetch failed) --
  /// posting must still work with the plain URL.
  bool get isAttachable => eligible && !internal;

  factory LinkPreview.fromJson(Map<String, dynamic> json) {
    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return LinkPreview(
      eligible: json['eligible'] == true,
      internal: json['internal'] == true,
      sourceUrl: str(json['sourceUrl']) ?? '',
      canonicalUrl: str(json['canonicalUrl']),
      linkPreviewId: str(json['linkPreviewId']),
      status: str(json['status']) ?? 'INELIGIBLE',
      title: str(json['title']),
      description: str(json['description']),
      siteName: str(json['siteName']),
      imageUrl: str(json['imageUrl']),
      faviconUrl: str(json['faviconUrl']),
    );
  }
}
