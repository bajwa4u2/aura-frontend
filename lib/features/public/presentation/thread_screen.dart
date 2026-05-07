import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../feed/presentation/feed_interaction_bar.dart';
import '../../posts/data/reactions_repository.dart';
import '../../institutions/ui/institution_ds.dart';
import '../widgets/reply_unit.dart';
import '../widgets/thread_header.dart';

/// Generalized thread screen — works for both `FeedItemType.userPost`
/// and `FeedItemType.institutionPost`. Reuses the existing
/// `feedItemDetailProvider` + `feedItemRepliesProvider` that already
/// support both types via `FeedItemDetailArgs`.
///
/// Layout:
///   * AppBar with Back + Share + More.
///   * `ThreadHeader` (original signal at full weight).
///   * Filter chips: All / Institution responses (in-place filter, no
///     extra fetch).
///   * Replies list (`ReplyUnit`).
///   * Sticky bottom composer entry — single tap routes to the existing
///     `/compose` flow with the right reply query params already wired.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({
    super.key,
    required this.postId,
    this.type = FeedItemType.userPost,
    this.parentInstitutionId,
  });

  final String postId;

  /// Defaults to `userPost`; the route layer passes `institutionPost`
  /// when the URL came from an institution-post link.
  final FeedItemType type;

  /// Required when [type] is `institutionPost` so the reply composer
  /// can route through `/institutions/:institutionId/posts/:postId/replies`
  /// rather than the user-reply path.
  final String? parentInstitutionId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

enum _ReplyFilter { all, institutions }

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  _ReplyFilter _filter = _ReplyFilter.all;

  FeedItemDetailArgs get _args =>
      FeedItemDetailArgs(type: widget.type, id: widget.postId);

  void _composeReply() {
    // Reuse the canonical compose flow. The compose screen already
    // handles draft persistence, validation, media, and publish — we
    // never fork that.
    final qp = <String, String>{};
    if (widget.type == FeedItemType.institutionPost) {
      qp['replyToInstitutionPostId'] = widget.postId;
      final parent = widget.parentInstitutionId?.trim() ?? '';
      if (parent.isNotEmpty) qp['parentInstitutionId'] = parent;
    } else {
      qp['replyTo'] = widget.postId;
    }
    final qs = qp.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    context.push('/compose?$qs').then((result) {
      if (result == true) {
        ref.invalidate(feedItemRepliesProvider(_args));
        ref.invalidate(feedItemDetailProvider(_args));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(feedItemDetailProvider(_args));
    final repliesAsync = ref.watch(feedItemRepliesProvider(_args));

    return AuraScaffold(
      showHeader: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ThreadAppBar(
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/'),
              onShare: () {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Sharing coming soon — copy the URL for now.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            Expanded(
              child: detailAsync.when(
                loading: () => const Center(
                  child: AuraLoadingState(message: 'Loading thread…'),
                ),
                error: (e, _) => InsScreen(
                  children: [
                    AuraErrorState(
                      title: 'Could not load this thread',
                      body: '$e',
                      action: AuraSecondaryButton(
                        label: 'Try again',
                        icon: Icons.refresh_rounded,
                        onPressed: () =>
                            ref.invalidate(feedItemDetailProvider(_args)),
                      ),
                    ),
                  ],
                ),
                data: (item) {
                  if (item == null) {
                    return const InsScreen(
                      children: [
                        InsEmptyState(
                          icon: Icons.help_outline_rounded,
                          title: 'Thread not found',
                          description:
                              'It may have been removed or is no longer visible to you.',
                        ),
                      ],
                    );
                  }
                  final isOfficial = item.type ==
                          FeedItemType.institutionPost &&
                      (item.title?.trim().isNotEmpty ?? false);

                  return InsScreen(
                    children: [
                      ThreadHeader(item: item),
                      const SizedBox(height: AuraSpace.s10),
                      FeedInteractionBar(
                        target: _reactionTargetFor(item),
                        visibility: item.interaction,
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      const _SectionLabel(label: 'Discussion'),
                      const SizedBox(height: AuraSpace.s8),
                      _FilterChips(
                        current: _filter,
                        onChange: (v) => setState(() => _filter = v),
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      repliesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(AuraSpace.s16),
                          child: AuraLoadingState(message: 'Loading replies…'),
                        ),
                        error: (e, _) => AuraErrorState(
                          title: 'Could not load replies',
                          body: '$e',
                          action: AuraSecondaryButton(
                            label: 'Try again',
                            icon: Icons.refresh_rounded,
                            onPressed: () =>
                                ref.invalidate(feedItemRepliesProvider(_args)),
                          ),
                        ),
                        data: (page) {
                          // Split replies into two bands so
                          // institutional voices read as a distinct,
                          // promoted strand. Filter chip can narrow to
                          // institutions-only.
                          final officials = page.items.where((r) {
                            final ctx = r.author.context;
                            return ctx != null &&
                                ctx.type ==
                                    FeedIdentityContextType
                                        .officialInstitution;
                          }).toList(growable: false);
                          final members = page.items.where((r) {
                            final ctx = r.author.context;
                            return !(ctx != null &&
                                ctx.type ==
                                    FeedIdentityContextType
                                        .officialInstitution);
                          }).toList(growable: false);

                          final showOfficials =
                              officials.isNotEmpty;
                          final showMembers =
                              members.isNotEmpty &&
                                  _filter == _ReplyFilter.all;

                          if (!showOfficials && !showMembers) {
                            return _NoRepliesEmpty(
                              onJoin: _composeReply,
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showOfficials) ...[
                                _OfficialRepliesBand(
                                  officials: officials,
                                ),
                                if (showMembers)
                                  const SizedBox(
                                      height: AuraSpace.s14),
                              ],
                              if (showMembers) ...[
                                const _SectionLabel(
                                    label: 'Member replies'),
                                const SizedBox(height: AuraSpace.s8),
                                for (var i = 0;
                                    i < members.length;
                                    i++) ...[
                                  ReplyUnit(
                                    reply: members[i],
                                    parentIsOfficial: isOfficial,
                                  ),
                                  if (i < members.length - 1)
                                    const SizedBox(
                                        height: AuraSpace.s10),
                                ],
                              ],
                              const SizedBox(height: AuraSpace.s14),
                              _JoinDiscussionCue(
                                onTap: _composeReply,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AuraSpace.s24),
                    ],
                  );
                },
              ),
            ),
            _StickyReplyBar(onTap: _composeReply),
          ],
        ),
      ),
    );
  }

  /// Builds the right reaction target so the existing FeedInteractionBar
  /// works on either user posts or institution posts.
  ReactionTarget _reactionTargetFor(FeedItem item) {
    switch (item.type) {
      case FeedItemType.userPost:
        return PostReactionTarget(item.id);
      case FeedItemType.institutionPost:
        // Resolve institution id from item.author when type is institution.
        final authorId = item.author.id;
        return InstitutionPostReactionTarget(
          institutionId: widget.parentInstitutionId?.trim().isNotEmpty == true
              ? widget.parentInstitutionId!.trim()
              : authorId,
          postId: item.id,
        );
    }
  }
}

class _ThreadAppBar extends StatelessWidget {
  const _ThreadAppBar({required this.onBack, required this.onShare});

  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: AuraSpace.s6,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: AuraSurface.muted,
            onPressed: onBack,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            color: AuraSurface.muted,
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        fontSize: 10,
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.current, required this.onChange});

  final _ReplyFilter current;
  final ValueChanged<_ReplyFilter> onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s8,
      children: [
        _Chip(
          label: 'All replies',
          selected: current == _ReplyFilter.all,
          onTap: () => onChange(_ReplyFilter.all),
        ),
        _Chip(
          label: 'Institution responses',
          selected: current == _ReplyFilter.institutions,
          onTap: () => onChange(_ReplyFilter.institutions),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected
                ? AuraSurface.accent.withValues(alpha: 0.4)
                : AuraSurface.divider,
          ),
        ),
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: selected ? AuraSurface.accentText : AuraSurface.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StickyReplyBar extends StatelessWidget {
  const _StickyReplyBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuraSurface.subtle,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s14,
              vertical: AuraSpace.s10,
            ),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AuraSurface.divider)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s10),
                Expanded(
                  child: Text(
                    'Reply to this discussion',
                    style: AuraText.body.copyWith(
                      color: AuraSurface.muted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                AuraPrimaryButton(
                  label: 'Reply',
                  icon: Icons.reply_rounded,
                  onPressed: onTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Promoted band for institutional responses. Sits at the top of the
/// replies area so the authoritative voices are unmistakable. Each
/// reply renders as a normal `ReplyUnit` (preserves the inline reading
/// stream); the band is just a labeled wrapper.
class _OfficialRepliesBand extends StatelessWidget {
  const _OfficialRepliesBand({required this.officials});

  final List<FeedReply> officials;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s10,
        AuraSpace.s12,
        AuraSpace.s10,
        AuraSpace.s12,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AuraSpace.s4, bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 12,
                  color: AuraSurface.accentText,
                ),
                const SizedBox(width: 4),
                Text(
                  officials.length == 1
                      ? 'OFFICIAL RESPONSE'
                      : 'OFFICIAL RESPONSES (${officials.length})',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < officials.length; i++) ...[
            ReplyUnit(
              reply: officials[i],
              parentIsOfficial: true,
            ),
            if (i < officials.length - 1)
              const SizedBox(height: AuraSpace.s10),
          ],
        ],
      ),
    );
  }
}

/// Empty-state widget when there are no replies yet — lifts a "Join
/// the discussion" CTA so the thread doesn't read as dead space.
class _NoRepliesEmpty extends StatelessWidget {
  const _NoRepliesEmpty({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s14,
        vertical: AuraSpace.s18,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.forum_outlined,
            size: 22,
            color: AuraSurface.muted,
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'No replies yet — be the first',
            style: AuraText.subtitle,
          ),
          const SizedBox(height: 4),
          Text(
            'This is public discourse. Anyone can reply, including '
            'institutional voices. Your statement will sit alongside theirs.',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraPrimaryButton(
            label: 'Join the discussion',
            icon: Icons.reply_rounded,
            onPressed: onJoin,
          ),
        ],
      ),
    );
  }
}

/// Calm "Join the discussion" cue rendered after the visible replies.
/// Pairs the sticky bottom composer at the bottom of the screen — but
/// is in-flow so it survives keyboards and small screens.
class _JoinDiscussionCue extends StatelessWidget {
  const _JoinDiscussionCue({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s10,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.md),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 14,
                color: AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(
                  'Join the discussion — your reply lands here.',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AuraSurface.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
