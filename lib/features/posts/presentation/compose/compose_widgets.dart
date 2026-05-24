import 'package:flutter/material.dart';

import '../../../../core/media/attachment.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VISIBILITY CHIP
// ─────────────────────────────────────────────────────────────────────────────

class ComposeVisibilityChip extends StatelessWidget {
  const ComposeVisibilityChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.card : AuraSurface.page,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Text(
          label,
          style: selected
              ? AuraText.body.copyWith(fontWeight: FontWeight.w700)
              : AuraText.small.copyWith(color: AuraSurface.muted),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTACHMENT ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class ComposeAttachmentActionButton extends StatelessWidget {
  const ComposeAttachmentActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AuraSecondaryButton(label: label, icon: icon, onPressed: onTap),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTACHMENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class ComposeAttachmentCard extends StatelessWidget {
  const ComposeAttachmentCard({
    super.key,
    required this.attachment,
    required this.captionController,
    required this.index,
    required this.count,
    required this.busy,
    required this.onRemove,
    this.onMoveLeft,
    this.onMoveRight,
  });

  final Attachment attachment;
  // Caption controller is owned by the screen-level State now (one parallel
  // map keyed by `attachment.localId`) — see compose_screen.dart. Passed
  // explicitly so this widget remains stateless and the model stays UI-free.
  final TextEditingController captionController;
  final int index;
  final int count;
  final bool busy;
  final VoidCallback onRemove;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  String _durationText(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return '';
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  attachment.isImage
                      ? 'Image ${index + 1}'
                      : 'Video ${index + 1}',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (attachment.uploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (!attachment.uploading)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          ComposeAttachmentPreview(attachment: attachment),
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              if (onMoveLeft != null)
                IconButton(
                  onPressed: busy ? null : onMoveLeft,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Move left',
                ),
              if (onMoveRight != null)
                IconButton(
                  onPressed: busy ? null : onMoveRight,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Move right',
                ),
              const Spacer(),
              Text(
                '${index + 1}/$count',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
          if (attachment.isVideo &&
              _durationText(attachment.durationMs).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: Text(
                _durationText(attachment.durationMs),
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ),
          if ((attachment.error ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: Text(
                attachment.error!,
                style: AuraText.small.copyWith(color: AuraSurface.coSun),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AuraSurface.divider),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s10,
              vertical: AuraSpace.s8,
            ),
            child: TextField(
              controller: captionController,
              enabled: !busy && !attachment.uploading,
              maxLines: null,
              minLines: 2,
              style: AuraText.body,
              decoration: InputDecoration(
                hintText: 'Caption for this attachment (optional)',
                hintStyle: AuraText.small.copyWith(color: AuraSurface.muted),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTACHMENT PREVIEW
// ─────────────────────────────────────────────────────────────────────────────

class ComposeAttachmentPreview extends StatelessWidget {
  const ComposeAttachmentPreview({super.key, required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      if (attachment.bytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: _aspectRatio(),
            child: Image.memory(
              attachment.bytes!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        );
      }

      final imageUrl = (attachment.thumbUrl ?? attachment.url ?? '').trim();
      if (imageUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: _aspectRatio(),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => _fallbackPreview(),
            ),
          ),
        );
      }

      return _fallbackPreview();
    }

    final thumbUrl = (attachment.thumbUrl ?? '').trim();
    if (thumbUrl.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                thumbUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => _videoFallback(),
              ),
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white),
          ),
        ],
      );
    }

    return _videoFallback();
  }

  double _aspectRatio() {
    final w = attachment.width;
    final h = attachment.height;
    if (w != null && h != null && w > 0 && h > 0) {
      var ratio = w / h;
      if (ratio < 0.7) ratio = 0.7;
      if (ratio > 1.8) ratio = 1.8;
      return ratio;
    }
    return 4 / 3;
  }

  Widget _fallbackPreview() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: AuraSurface.muted,
        size: 36,
      ),
    );
  }

  Widget _videoFallback() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_outlined,
            color: AuraSurface.muted,
            size: 36,
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            attachment.file?.name ?? attachment.fileName ?? 'Video attachment',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
