class PostCardResolvedMediaItem {
  const PostCardResolvedMediaItem({
    required this.id,
    required this.type,
    required this.url,
    required this.thumbUrl,
    required this.caption,
    required this.width,
    required this.height,
    required this.duration,
    required this.editDisclosure,
  });

  final String id;
  final String type;
  final String? url;
  final String? thumbUrl;
  final String? caption;
  final int? width;
  final int? height;
  final int? duration;
  final bool editDisclosure;

  bool get isVideo => type.toUpperCase().contains('VIDEO');
  bool get isSvg =>
      type.toUpperCase().contains('SVG') ||
      ((url ?? '').toLowerCase().endsWith('.svg'));

  String get playableUrl => (url ?? '').trim();

  /// The server's poster for this media, or empty when it has none.
  ///
  /// For video this is empty for everything the product has ever stored: the
  /// backend sets a thumbnail only for images. Producing a picture of a video
  /// is the video surface's problem, not this model's.
  String get posterUrl => (thumbUrl ?? '').trim();

  /// A URL safe to hand to an IMAGE decoder.
  ///
  /// It previously fell back to [playableUrl] for a poster-less video, so an
  /// MP4 was passed to the image pipeline, failed to decode, and rendered as a
  /// broken-image tile. A video URL is never an image URL, and saying so here
  /// is what stops every consumer of this model from repeating the mistake.
  String get previewUrl {
    if (isVideo) return posterUrl;
    return playableUrl;
  }
}
