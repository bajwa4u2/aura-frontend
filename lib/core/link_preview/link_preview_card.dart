import 'package:flutter/material.dart';

import '../../features/posts/presentation/widgets/post_card/post_card_utils.dart';
import '../media/aura_attachment_image.dart';
import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';

/// Compose Link Intelligence / OG Preview -- Phase 1.
///
/// The one canonical link-preview card, consumed both at compose time
/// (draft preview, fed from a `LinkPreview` resolve result) and at
/// render time (published posts, fed from a Post/FeedItem's flat
/// `linkUrl`/`linkTitle`/... fields) -- deliberately parameterized on
/// plain strings rather than requiring either shape, so both contexts
/// share the exact same rendering without an adapter class.
///
/// Degrades gracefully: with no title/image, it still renders as a
/// clickable domain/url row rather than disappearing or looking broken.
class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    super.key,
    required this.url,
    this.title,
    this.description,
    this.siteName,
    this.imageUrl,
    this.dense = false,
    this.onRemove,
  });

  final String url;
  final String? title;
  final String? description;
  final String? siteName;
  final String? imageUrl;

  /// Compact chrome for the compose-time draft card (adds a remove
  /// action); the published-render card omits it.
  final bool dense;
  final VoidCallback? onRemove;

  String get _host {
    try {
      final host = Uri.parse(url).host;
      return host.isNotEmpty ? host : (siteName ?? url);
    } catch (_) {
      return siteName ?? url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = (title ?? '').trim();
    final displayDescription = (description ?? '').trim();

    return InkWell(
      onTap: () => openExternalUrl(context, url),
      onLongPress: () => copyToClipboard(context, url, message: 'Link copied'),
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        decoration: BoxDecoration(
          color: AuraSurface.card,
          border: Border.all(color: AuraSurface.divider),
          borderRadius: BorderRadius.circular(AuraRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((imageUrl ?? '').isNotEmpty)
              SizedBox(
                width: dense ? 72 : 96,
                height: dense ? 72 : 96,
                child: AuraAttachmentImage(
                  url: imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_) => const SizedBox.shrink(),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AuraSpace.s10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _host,
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.faint,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (displayTitle.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (displayDescription.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        displayDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                    if (displayTitle.isEmpty && displayDescription.isEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.small.copyWith(color: AuraSurface.accentText),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (onRemove != null)
              Padding(
                padding: const EdgeInsets.all(AuraSpace.s6),
                child: InkWell(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(AuraSpace.s4),
                    child: Icon(Icons.close, size: 16, color: AuraSurface.muted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
