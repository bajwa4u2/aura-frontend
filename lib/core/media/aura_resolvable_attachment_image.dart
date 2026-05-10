import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/aura_surface.dart';
import 'aura_attachment_image.dart';
import 'media_url_resolver.dart';

/// Canonical image renderer for media that MAY be RESTRICTED or PRIVATE.
///
/// PUBLIC media: callers should keep using [AuraAttachmentImage] with
/// the URL they already have from the surrounding payload — there is no
/// network round-trip required.
///
/// RESTRICTED / PRIVATE media: callers pass the [mediaId] only. This
/// widget asks the canonical [MediaUrlResolver] (via Riverpod) for a
/// short-lived signed URL, renders through [AuraAttachmentImage] once
/// resolved, and shows the supplied [placeholder] / [errorWidget] for
/// the loading and failure states.
///
/// Visibility is determined server-side, so callers don't need to know
/// the row's visibility ahead of time — public media will resolve in
/// one round-trip and cache effectively forever; restricted media will
/// resolve to a fresh signed URL.
class AuraResolvableAttachmentImage extends ConsumerWidget {
  const AuraResolvableAttachmentImage({
    super.key,
    required this.mediaId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  /// Server-issued Media id. Required.
  final String mediaId;

  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final String? semanticLabel;
  final BorderRadius? borderRadius;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mediaUrlProvider(mediaId));
    return async.when(
      data: (result) => AuraAttachmentImage(
        url: result.url,
        attachmentId: mediaId,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        semanticLabel: semanticLabel,
        borderRadius: borderRadius,
        placeholder: placeholder,
        errorWidget: errorWidget,
      ),
      loading: () => _wrap(_buildPlaceholder(context)),
      error: (_, __) => _wrap(_buildError(context)),
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
