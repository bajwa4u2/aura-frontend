import 'dart:async';

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
class AuraResolvableAttachmentImage extends ConsumerStatefulWidget {
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
  ConsumerState<AuraResolvableAttachmentImage> createState() =>
      _AuraResolvableAttachmentImageState();
}

class _AuraResolvableAttachmentImageState
    extends ConsumerState<AuraResolvableAttachmentImage> {
  /// STILL PROCESSING IS A STATE TO WAIT THROUGH, NOT ONE TO GIVE UP ON.
  ///
  /// The resolver drops a failed entry after a short cooldown, but nothing
  /// re-read it, so a picture thirty seconds from ready stayed broken until
  /// the widget happened to rebuild. Re-asking is bounded so a row that is
  /// permanently not-ready cannot become a polling loop.
  static const int _maxPendingRetries = 4;

  Timer? _retry;
  int _attempts = 0;

  @override
  void didUpdateWidget(covariant AuraResolvableAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different object is a different question; the previous one's attempts
    // say nothing about it.
    if (oldWidget.mediaId != widget.mediaId) {
      _retry?.cancel();
      _retry = null;
      _attempts = 0;
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retry != null || _attempts >= _maxPendingRetries) return;
    // Widening backoff: 2s, 4s, 8s, 16s. Processing finishes in seconds, and
    // a queue that is behind should not be asked harder.
    final delay = Duration(seconds: 2 << _attempts);
    _attempts += 1;
    _retry = Timer(delay, () {
      _retry = null;
      if (!mounted) return;
      ref.invalidate(mediaUrlProvider(widget.mediaId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mediaUrlProvider(widget.mediaId));
    return async.when(
      data: (result) => AuraAttachmentImage(
        url: result.url,
        attachmentId: widget.mediaId,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        alignment: widget.alignment,
        semanticLabel: widget.semanticLabel,
        borderRadius: widget.borderRadius,
        placeholder: widget.placeholder,
        errorWidget: widget.errorWidget,
      ),
      loading: () => _wrap(_buildPlaceholder(context)),
      error: (e, __) {
        if (e is MediaUnavailableException) {
          if (e.isPending) {
            // Not an error yet. Keep the calm placeholder the loading state
            // already uses — a broken-image icon would state something untrue
            // about media that is on its way — and ask again shortly.
            _scheduleRetry();
            return _wrap(_buildPlaceholder(context));
          }
          if (e.isQuarantined) return _wrap(_buildWithheld(context, e));
        }
        return _wrap(_buildError(context));
      },
    );
  }

  Widget _wrap(Widget child) {
    if (widget.borderRadius == null) return child;
    return ClipRRect(borderRadius: widget.borderRadius!, child: child);
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (widget.placeholder != null) return widget.placeholder!(context);
    return Container(
      width: widget.width,
      height: widget.height,
      color: AuraSurface.subtle,
    );
  }

  /// WITHHELD, NOT DESTROYED.
  ///
  /// Quarantine is reversible retention, and the door says so deliberately
  /// rather than answering 404. A broken-image icon here would tell the owner
  /// their file is gone and leave them nothing to act on, so the server's own
  /// sentence is shown — it carries no detector internals by contract.
  Widget _buildWithheld(BuildContext context, MediaUnavailableException e) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AuraSurface.subtle,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.visibility_off_outlined,
            size: 24,
            color: AuraSurface.faint,
          ),
          const SizedBox(height: 6),
          Text(
            e.message?.trim().isNotEmpty == true
                ? e.message!.trim()
                : 'This attachment is under review and is not currently '
                    'available.',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AuraSurface.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    if (widget.errorWidget != null) return widget.errorWidget!(context);
    return Container(
      width: widget.width,
      height: widget.height,
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
