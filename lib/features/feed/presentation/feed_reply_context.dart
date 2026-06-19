import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/unified_feed_providers.dart';
import '../domain/feed_item.dart';

/// "In reply to" context banner for a unified [FeedItem] detail surface.
///
/// Guarantees a reply is never shown detached from the original it answers:
/// when [item] is a reply, this fetches the parent (user or institution post)
/// and renders the original's author + snippet, tapping through to its full
/// thread. Renders nothing when [item] is a root post.
class FeedReplyContext extends ConsumerWidget {
  const FeedReplyContext({super.key, required this.item});

  final FeedItem item;

  FeedItemDetailArgs? get _parentArgs {
    final up = (item.replyToPostId ?? '').trim();
    if (up.isNotEmpty) {
      return FeedItemDetailArgs(type: FeedItemType.userPost, id: up);
    }
    final ip = (item.replyToInstitutionPostId ?? '').trim();
    if (ip.isNotEmpty) {
      return FeedItemDetailArgs(type: FeedItemType.institutionPost, id: ip);
    }
    return null;
  }

  Widget _frame(BuildContext context, {required Widget child, VoidCallback? onTap}) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.card),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _eyebrow({String trailing = ''}) {
    return Row(
      children: [
        const Icon(Icons.reply_rounded, size: 14, color: AuraSurface.muted),
        const SizedBox(width: 6),
        Text(
          'In reply to',
          style: AuraText.micro.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        if (trailing.isNotEmpty) ...[
          const Spacer(),
          Text(
            trailing,
            style: AuraText.micro.copyWith(
              color: AuraSurface.accentText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = item.parentTargetRoute;
    final args = _parentArgs;
    if (route == null || args == null) return const SizedBox.shrink();

    final parentAsync = ref.watch(feedItemDetailProvider(args));

    return parentAsync.when(
      // While loading (or on error) still show the linked banner so the reply
      // is never visually detached — the original is always one tap away.
      loading: () => _frame(
        context,
        onTap: () => context.go(route),
        child: _eyebrow(trailing: 'View original →'),
      ),
      error: (_, __) => _frame(
        context,
        onTap: () => context.go(route),
        child: _eyebrow(trailing: 'View original →'),
      ),
      data: (parent) {
        if (parent == null) {
          return _frame(
            context,
            onTap: () => context.go(route),
            child: _eyebrow(trailing: 'View original →'),
          );
        }
        final name = parent.author.name.trim().isNotEmpty
            ? parent.author.name
            : (parent.author.handleOrSlug.trim().isNotEmpty
                ? '@${parent.author.handleOrSlug}'
                : 'Original post');
        final snippet = parent.body.trim().replaceAll('\n', ' ');
        final short =
            snippet.length > 160 ? '${snippet.substring(0, 160)}…' : snippet;
        return _frame(
          context,
          onTap: () => context.go(route),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _eyebrow(trailing: 'View original →'),
              const SizedBox(height: AuraSpace.s8),
              Text(
                name,
                style: AuraText.small.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (short.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  short,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
