import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../ui/aura_surface.dart';
import 'attachment_url.dart';

/// Canonical image-attachment renderer. Replaces ad-hoc `Image.network`
/// calls scattered across post cards, message tiles, announcement
/// detail, and feed cards.
///
/// Goals:
///   * one cache key strategy for every attachment image — keyed by the
///     server-issued `mediaId` / `attachmentId` whenever available, so
///     replacing media server-side invalidates the cached image cleanly.
///   * one error fallback — uniform "image unavailable" tile across
///     surfaces (post card, message tile, feed card, announcement
///     detail all rendered different fallbacks before).
///   * one loading placeholder — uses the platform's standard subtle
///     surface tint instead of an ad-hoc CircularProgressIndicator.
///
/// The widget intentionally does NOT subscribe to attachment-payload
/// shape directly — callers pass a resolved `url` and an optional
/// `attachmentId`. `resolveAttachmentUrl(payload)` from
/// `attachment_url.dart` is the recommended way to extract the URL
/// upstream of this widget.
class AuraAttachmentImage extends StatelessWidget {
  const AuraAttachmentImage({
    super.key,
    required this.url,
    this.attachmentId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  /// Resolved absolute URL. Use [resolveAttachmentUrl] to extract from
  /// a backend payload before passing in.
  final String url;

  /// Server-issued id, used as the cache key. When null, falls back to
  /// the URL string — same as `CachedNetworkImage`'s default. Passing
  /// the id is strongly preferred so replacing the underlying file
  /// doesn't require an app restart.
  final String? attachmentId;

  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final String? semanticLabel;
  final BorderRadius? borderRadius;

  /// Override the default subtle placeholder.
  final WidgetBuilder? placeholder;

  /// Override the default "image unavailable" fallback.
  final WidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return _wrap(_buildError(context));
    }

    final image = CachedNetworkImage(
      imageUrl: trimmed,
      cacheKey: attachmentId?.trim().isNotEmpty == true
          ? 'aura_attachment:$attachmentId'
          : null,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      placeholder: (context, _) => _buildPlaceholder(context),
      errorWidget: (context, _, __) => _buildError(context),
    );

    return _wrap(
      Semantics(
        image: true,
        label: semanticLabel,
        child: image,
      ),
    );
  }

  Widget _wrap(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (placeholder != null) return placeholder!(context);
    return Container(
      width: width,
      height: height,
      color: AuraSurface.subtle,
    );
  }

  Widget _buildError(BuildContext context) {
    if (errorWidget != null) return errorWidget!(context);
    return Container(
      width: width,
      height: height,
      color: AuraSurface.subtle,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        size: 28,
        color: AuraSurface.faint,
      ),
    );
  }
}
