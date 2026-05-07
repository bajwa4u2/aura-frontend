import 'package:flutter/material.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_item.dart';

/// Discourse activity tail — single calm line beneath the body that
/// signals what's happening *around* this item:
///
///     12 replies · 3 institutions responded · Active discussion
///
/// Returns a zero-height widget when there's nothing meaningful to say
/// (no replies, no recent activity). Uses only existing fields on
/// `FeedItem.interaction` and `FeedItem.activity` / `FeedItem.replyPreview`.
class ActivityTail extends StatelessWidget {
  const ActivityTail({super.key, required this.item});

  final FeedItem item;

  /// Count of *distinct* official institution voices in the reply
  /// preview. Conservative: only counts replies whose author identity
  /// context is `officialInstitution` (the same gate used elsewhere
  /// for "Official response").
  int get _institutionResponseCount {
    final preview = item.replyPreview;
    if (preview == null || preview.items.isEmpty) return 0;
    final seen = <String>{};
    var n = 0;
    for (final r in preview.items) {
      final ctx = r.author.context;
      if (ctx == null) continue;
      if (ctx.type != FeedIdentityContextType.officialInstitution) continue;
      if (r.author.id.isEmpty || seen.contains(r.author.id)) continue;
      seen.add(r.author.id);
      n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final segments = <String>[];

    final inter = item.interaction;
    if (inter.canViewReplyCount && inter.replyCount > 0) {
      segments.add(
        inter.replyCount == 1 ? '1 reply' : '${inter.replyCount} replies',
      );
    }

    final insN = _institutionResponseCount;
    if (insN > 0) {
      segments.add(
        insN == 1
            ? '1 institution responded'
            : '$insN institutions responded',
      );
    }

    if (item.activity?.recentReply == true) {
      segments.add('Active discussion');
    }

    if (segments.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.forum_outlined,
          size: 12,
          color: AuraSurface.muted,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            segments.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tap-to-jump button rendered alongside the activity tail when there
/// IS active discussion — gives users a one-tap entry to the latest
/// reply rather than the top of the thread.
class ActivityJumpButton extends StatelessWidget {
  const ActivityJumpButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s6,
          vertical: 2,
        ),
        child: Text(
          'Jump in',
          style: AuraText.small.copyWith(
            color: AuraSurface.accentText,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
