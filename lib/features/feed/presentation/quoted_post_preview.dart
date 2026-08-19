import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/post.dart';

/// Compact embedded card for the original post a reshare-with-commentary
/// points to. Without this, a repost is indistinguishable from a plain new
/// post — the whole point of a quote-repost is showing both together.
class QuotedPostPreview extends StatelessWidget {
  const QuotedPostPreview({super.key, required this.original});

  final Post original;

  @override
  Widget build(BuildContext context) {
    final author = original.author;
    // F053 — this surface used to re-decide the name/handle/neutral-word
    // order for itself. It now asks the identity for its own label.
    final name = author?.label ?? 'Someone';
    final handle = (author?.handle.trim().isNotEmpty ?? false)
        ? '@${author!.handle.trim()}'
        : null;
    final text = original.displayText().trim();

    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      onTap: original.id.isEmpty
          ? null
          : () => context.push('/posts/${original.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AuraSpace.s12),
        decoration: BoxDecoration(
          border: Border.all(color: AuraSurface.divider),
          borderRadius: BorderRadius.circular(AuraRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AuraAvatar(name: name, imageUrl: author?.avatarUrl, size: 22),
                const SizedBox(width: AuraSpace.s8),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (handle != null && handle != name) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ),
                ],
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s6),
              Text(
                text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AuraText.small.copyWith(color: AuraSurface.ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
