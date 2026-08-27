/// THE COMPOSITION STRIP — what the author is about to send, shown honestly.
///
/// One place, for every composer, that answers:
///
///     WHAT IS ATTACHED   what kind, and what it looks like
///     IN WHAT ORDER      author intent, rearrangeable
///     IN WHAT STATE      local / uploading / failed / ready, PER ITEM
///
/// ## WHY THIS IS NOT A ROW OF PILLS
///
/// A composer that shows "4 files attached" has hidden the composition from
/// the person composing it. Worse, the strip this replaces previewed local
/// bytes for images and fell through to a GLYPH for video — so the one media
/// kind whose content is least guessable from a filename was the one shown as
/// an icon.
///
/// Video here renders through the canonical stored-media authority from its
/// LOCAL source, so it looks like the video it is before anything has been
/// uploaded, and keeps looking like it while the upload is in flight.
///
/// ## WHY STATE IS PER ITEM
///
/// Multi-media makes upload a distributed problem, and one global spinner
/// cannot express it. Four items where the third failed is a real and common
/// state; collapsing it to "uploading…" and then quietly sending three of four
/// is the failure this whole chapter exists to prevent.
library;

import 'package:flutter/material.dart';

import '../composition/attachment_lifecycle.dart';
import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'attachment.dart';
import 'aura_stored_media.dart';
import 'stored_media.dart';

/// Ordered, rearrangeable preview of a composition's media.
class AuraCompositionStrip extends StatelessWidget {
  const AuraCompositionStrip({
    super.key,
    required this.attachments,
    required this.phaseOf,
    required this.onRemove,
    this.onReorder,
    this.onRetry,
    this.tileSize = 92,
  });

  final List<Attachment> attachments;
  final AttachmentPhase Function(Attachment) phaseOf;
  final void Function(String localId) onRemove;

  /// Null on surfaces where order carries no meaning. Where it is supplied,
  /// the order the author arranges is the order persisted against
  /// `PostMedia.position` / `MessageMedia.position`.
  final void Function(int oldIndex, int newIndex)? onReorder;

  /// Retry ONE item. Successful siblings are never re-uploaded — recovering
  /// from one failure must not spend the person's bandwidth on work that
  /// already succeeded.
  final void Function(Attachment)? onRetry;

  final double tileSize;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final canReorder = onReorder != null && attachments.length > 1;

    return Semantics(
      label: '${attachments.length} attached, in order',
      child: SizedBox(
        height: tileSize + AuraSpace.s12,
        child: canReorder
            ? ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12, vertical: AuraSpace.s6),
                itemCount: attachments.length,
                onReorder: onReorder!,
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.transparent,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  child: child,
                ),
                itemBuilder: (context, i) {
                  final a = attachments[i];
                  // A long press is the touch idiom for "pick this up"; a
                  // dedicated drag handle on a 92px tile would be too small to
                  // hit and would crowd the remove control.
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(a.localId),
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AuraSpace.s6),
                      child: _tile(a, i),
                    ),
                  );
                },
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12, vertical: AuraSpace.s6),
                itemCount: attachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: AuraSpace.s6),
                itemBuilder: (context, i) => _tile(attachments[i], i),
              ),
      ),
    );
  }

  Widget _tile(Attachment a, int index) => _CompositionTile(
        attachment: a,
        phase: phaseOf(a),
        size: tileSize,
        position: index + 1,
        total: attachments.length,
        onRemove: () => onRemove(a.localId),
        onRetry: onRetry == null ? null : () => onRetry!(a),
      );
}

class _CompositionTile extends StatelessWidget {
  const _CompositionTile({
    required this.attachment,
    required this.phase,
    required this.size,
    required this.position,
    required this.total,
    required this.onRemove,
    this.onRetry,
  });

  final Attachment attachment;
  final AttachmentPhase phase;
  final double size;
  final int position;
  final int total;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = phase == AttachmentPhase.failed;
    final busy = AttachmentLifecycle.isPending(phase) && !failed;

    return Semantics(
      label: '${_kindLabel()} $position of $total, ${_stateLabel()}',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AuraRadius.md),
                child: Container(
                  decoration: BoxDecoration(
                    color: AuraSurface.subtle,
                    border: Border.all(
                      color:
                          failed ? AuraSurface.dangerInk : AuraSurface.divider,
                    ),
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                  ),
                  // THE CANONICAL AUTHORITY, from a LOCAL source. A video
                  // looks like its own first frame before it has been
                  // uploaded, rather than like a paperclip.
                  child: AuraStoredMedia(
                    media: _asStoredMedia(attachment),
                    context: StoredMediaContext.compose,
                  ),
                ),
              ),
            ),

            // Per-item progress. Not a global spinner: with several items in
            // flight, one spinner cannot say which of them is moving.
            if (busy)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AuraSurface.ink.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AuraRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: attachment.uploadProgress,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // Failure is explicit and RECOVERABLE. A failed item blocks the
            // send until the author retries or removes it, so it must be
            // obvious which item and what can be done about it.
            if (failed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AuraSurface.ink.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: onRetry == null
                      ? const Icon(Icons.error_outline_rounded,
                          color: AuraSurface.dangerInk)
                      : IconButton(
                          tooltip: 'Retry this item',
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white),
                        ),
                ),
              ),

            Positioned(
              top: 2,
              right: 2,
              child: _TileButton(
                icon: Icons.close_rounded,
                tooltip: 'Remove',
                onTap: onRemove,
              ),
            ),

            // Position is stated, not merely implied by layout — a horizontal
            // strip reads as an order visually and says nothing to anyone who
            // cannot see it.
            if (total > 1)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AuraSurface.ink.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$position',
                      style: AuraText.small.copyWith(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _kindLabel() {
    switch (attachment.kind) {
      case AttachmentKind.image:
        return 'Image';
      case AttachmentKind.video:
        return 'Video';
      case AttachmentKind.audio:
        return 'Audio';
      case AttachmentKind.document:
        return 'File';
    }
  }

  String _stateLabel() {
    switch (phase) {
      case AttachmentPhase.failed:
        return 'failed to upload, retry or remove it';
      case AttachmentPhase.uploading:
        return 'uploading';
      case AttachmentPhase.ready:
        return 'ready to send';
      case AttachmentPhase.rejected:
        return 'not accepted';
      case AttachmentPhase.cancelled:
        return 'removed';
      default:
        return 'preparing';
    }
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AuraSurface.ink.withValues(alpha: 0.66),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Adapter from a composing [Attachment] onto the canonical stored-media model.
///
/// Deliberately identical in shape to the post composer's own adapter: the
/// composing and the composed object are the SAME media, and the whole point
/// of the stored-media authority is that both take one path.
StoredMedia _asStoredMedia(Attachment a) {
  final url = (a.url ?? '').trim();
  final hydrated = url.isNotEmpty;
  return StoredMedia.fromParts(
    mediaId: a.mediaId ?? '',
    mimeType: a.mimeType,
    declaredKind: a.kind.name.toUpperCase(),
    isPublic: true,
    sourceUrl: hydrated ? url : null,
    posterUrl: a.thumbUrl,
    localBytes: a.bytes,
    localPath: a.file?.path,
    fileName: a.fileName ?? a.file?.name,
    width: a.width,
    height: a.height,
    durationMs: a.durationMs,
    // Local until the server issues identity, so the surface keeps showing the
    // person's own copy rather than blanking while bytes are in flight.
    state: hydrated
        ? StoredMediaState.ready
        : (a.uploading ? StoredMediaState.pending : StoredMediaState.local),
  );
}
