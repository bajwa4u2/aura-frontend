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
  String get previewUrl {
    if (isVideo) {
      final thumb = (thumbUrl ?? '').trim();
      if (thumb.isNotEmpty) return thumb;
      return playableUrl;
    }
    return playableUrl;
  }
}
