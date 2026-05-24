import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/rail/rail_composition.dart';
import '../../../config.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/surface/aura_discourse_surface.dart';
import '../../../core/utils/relative_time.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../feed/presentation/feed_interaction_bar.dart';
import '../../posts/data/reactions_repository.dart';
import '../../institutions/ui/institution_ds.dart';
import '../data/thread_last_seen_cache.dart';
import '../domain/accountability_tag.dart';
import '../domain/monetization_kind.dart';
import '../widgets/follow_button.dart';
import '../widgets/monetization_label.dart';
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
    this.focusTarget,
    this.focusReplyId,
  });

  final String postId;

  /// Defaults to `userPost`; the route layer passes `institutionPost`
  /// when the URL came from an institution-post link.
  final FeedItemType type;

  /// Required when [type] is `institutionPost` so the reply composer
  /// can route through `/institutions/:institutionId/posts/:postId/replies`
  /// rather than the user-reply path.
  final String? parentInstitutionId;

  /// Public-UX Phase 6.1 — entry-accuracy hint. Read from `?focus=`.
  /// Recognized values:
  ///   * `timeline`         → scroll to the accountability timeline
  ///   * `first-official`   → scroll to the first official reply
  ///   * `last-reply`       → scroll to the most recent member reply
  /// Anything else (or null) leaves scroll position alone.
  final String? focusTarget;

  /// Public-UX Phase 6.1 — focus a specific reply by id. Read from
  /// `?replyId=`. Wins over [focusTarget] when both are present.
  final String? focusReplyId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

enum _ReplyFilter { all, institutions }

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  _ReplyFilter _filter = _ReplyFilter.all;

  /// Public-UX Phase 3 — child index built each render. Maps a parent
  /// reply id to its direct children (sorted oldest → newest). Empty
  /// for replies with no children.
  Map<String, List<FeedReply>> _byParent = const {};

  /// Public-UX Phase 6 — last-seen timestamp for THIS thread, loaded
  /// async from SharedPreferences on initState. Replies created after
  /// this point render below a "New since you last visited" divider.
  /// Null on first load while the cache resolves; null on first-ever
  /// visit (no divider then — everything's new).
  DateTime? _lastSeenAt;
  bool _seenLoaded = false;

  /// Public-UX Phase 6.1 — scroll-to-focus keys + state.
  ///
  /// We attach `GlobalKey`s to the surfaces that route hints can target
  /// (timeline, first official, last member reply) plus a per-reply map
  /// for arbitrary `?replyId=` deep links. After the first build that
  /// renders the requested anchor, we run `Scrollable.ensureVisible`
  /// once and flip `_autoScrolled` so we don't yank the viewport again
  /// on later rebuilds.
  final GlobalKey _timelineKey = GlobalKey();
  final GlobalKey _firstOfficialKey = GlobalKey();
  final GlobalKey _lastReplyKey = GlobalKey();
  final Map<String, GlobalKey> _replyKeys = {};
  bool _autoScrolled = false;

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
  }

  GlobalKey _keyForReply(String replyId) =>
      _replyKeys.putIfAbsent(replyId, () => GlobalKey());

  /// Resolve which key (if any) the route asked us to focus. Returns
  /// null when no hint applies or the relevant widget hasn't mounted
  /// yet — callers should retry on the next frame in that case.
  GlobalKey? _resolveFocusKey() {
    final id = widget.focusReplyId?.trim();
    if (id != null && id.isNotEmpty) {
      return _replyKeys[id];
    }
    switch ((widget.focusTarget ?? '').trim().toLowerCase()) {
      case 'timeline':
        return _timelineKey.currentContext == null ? null : _timelineKey;
      case 'first-official':
        return _firstOfficialKey.currentContext == null
            ? null
            : _firstOfficialKey;
      case 'last-reply':
        return _lastReplyKey.currentContext == null ? null : _lastReplyKey;
    }
    return null;
  }

  void _maybeAutoScroll() {
    if (_autoScrolled) return;
    if (widget.focusReplyId == null && widget.focusTarget == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoScrolled) return;
      final key = _resolveFocusKey();
      final ctx = key?.currentContext;
      if (ctx == null) return; // anchor not built yet — retry next build
      _autoScrolled = true;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    });
  }

  Future<void> _loadLastSeen() async {
    final ts = await ThreadLastSeenCache.read(widget.postId);
    if (!mounted) return;
    setState(() {
      _lastSeenAt = ts;
      _seenLoaded = true;
    });
  }

  /// True when `members[i]` is the first reply newer than the cached
  /// `lastSeenAt`. Returns false when there's no previous reply
  /// (everything's "new" on first visit — no divider needed) and when
  /// the cache hasn't loaded yet.
  bool _isFirstNewReply(List<FeedReply> members, int i) {
    final last = _lastSeenAt;
    if (last == null) return false;
    final r = members[i];
    final ts = r.createdAt;
    if (ts == null) return false;
    if (!ts.isAfter(last)) return false;
    if (i == 0) return false;
    final prev = members[i - 1].createdAt;
    if (prev == null) return false;
    return !prev.isAfter(last);
  }

  /// Phase 6.1 — true when this reply landed after the cached
  /// `_lastSeenAt`. Used to apply the fade-in highlight tint.
  bool _isNewReply(FeedReply r) {
    final last = _lastSeenAt;
    if (last == null || !_seenLoaded) return false;
    final ts = r.createdAt;
    if (ts == null) return false;
    return ts.isAfter(last);
  }

  @override
  void dispose() {
    // Best-effort: stamp the current time on dispose so the next visit
    // has a fresh baseline. Fire-and-forget — we deliberately don't
    // await; SharedPreferences is fast enough on real devices.
    ThreadLastSeenCache.markSeenNow(widget.postId);
    super.dispose();
  }

  bool _isOfficialReply(FeedReply r) {
    final ctx = r.author.context;
    return ctx != null &&
        ctx.type == FeedIdentityContextType.officialInstitution;
  }

  /// Build the nested reply tree from a flat list. Replies with no
  /// `parentReplyId` are top-level; everything else slots under its
  /// parent (when the parent is in the list).
  List<FeedReply> _buildReplyTree(List<FeedReply> all) {
    final children = <String, List<FeedReply>>{};
    final ids = <String>{for (final r in all) r.id};
    final top = <FeedReply>[];
    for (final r in all) {
      final pid = r.parentReplyId;
      if (pid == null || !ids.contains(pid)) {
        top.add(r);
        continue;
      }
      children.putIfAbsent(pid, () => []).add(r);
    }
    for (final list in children.values) {
      list.sort((a, b) {
        final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return at.compareTo(bt);
      });
    }
    _byParent = children;
    return top;
  }

  /// PRIORITY paid replies are pinned to the top of the thread —
  /// rendered first, with the visible PRIORITY label.
  List<FeedReply> _priorityPinned(List<FeedReply> top) {
    return top
        .where((r) {
          final kind = MonetizationKindX.fromPaidActionWire(r.paidActionWire);
          return kind == MonetizationKind.priorityResponse;
        })
        .toList(growable: false);
  }

  /// Build the accountability timeline events. Includes only replies
  /// that carry a tag; ordered oldest → newest so the timeline reads
  /// as a real lifecycle (commitment → update → resolved).
  List<_TimelineEvent> _buildTimeline(List<FeedReply> all) {
    final events = <_TimelineEvent>[];
    for (final r in all) {
      final tag = InsAccountabilityTagX.fromWire(r.accountabilityTagWire);
      if (tag == null) continue;
      events.add(
        _TimelineEvent(
          tag: tag,
          when: r.createdAt,
          actorName: r.author.displayName.isNotEmpty
              ? r.author.displayName
              : (r.author.handle.isNotEmpty
                    ? '@${r.author.handle}'
                    : 'Institution'),
          replyId: r.id,
        ),
      );
    }
    events.sort((a, b) {
      final at = a.when?.millisecondsSinceEpoch ?? 0;
      final bt = b.when?.millisecondsSinceEpoch ?? 0;
      return at.compareTo(bt);
    });
    return events;
  }

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
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
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

    // Composer is allowed only when a real, accessible item is loaded. A 404
    // / 403 / null item means there's nothing to reply to — leaving the
    // composer mounted produced "broken thread with active reply bar".
    final canCompose = detailAsync.maybeWhen(
      data: (item) => item != null,
      orElse: () => false,
    );

    return AuraScaffold(
      showHeader: false,
      // Discourse detail composition: the page widens to host a
      // contextual rail beside the thread. AuraDiscourseSurface keeps
      // the thread (header + replies + composer) at the kReadWidth
      // reading measure and drops the rail at laptop / mobile widths.
      maxWidth: kWorkspaceWidth,
      body: SafeArea(
        bottom: false,
        child: AuraDiscourseSurface(
          railModules: discourseDetailRailModules(),
          reading: Column(
            children: [
              _ThreadAppBar(
                // Phase 6.1 — show the Follow toggle only on user-post
                // threads (the backend follow target is `Post`, not
                // `InstitutionPost`).
                followablePostId: widget.type == FeedItemType.userPost
                    ? widget.postId
                    : null,
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                onShare: () async {
                  // Native share intent isn't shipped on every platform
                  // path yet (Web Share API + iOS/Android share sheets).
                  // Until the unified share surface lands, do the most
                  // useful concrete thing: copy the canonical thread URL
                  // to the clipboard. No dead-end snackbar; the user
                  // gets something they can paste.
                  final base =
                      Uri.tryParse(
                        AppConfig.publicWebUrl,
                      )?.toString().trimRight() ??
                      '';
                  final path = widget.type == FeedItemType.institutionPost
                      ? '/institutions/posts/${widget.postId}'
                      : '/posts/${widget.postId}';
                  final url = base.isNotEmpty ? '$base$path' : path;
                  await Clipboard.setData(ClipboardData(text: url));
                  if (!context.mounted) return;
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard.'),
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
                  error: (e, _) {
                    // Translate the underlying error into safe user copy. We
                    // must NOT show "DioException" or "Instance of 'minified:…'"
                    // — that's the production leakage the audit flagged.
                    final view = _ThreadErrorView.fromError(e);
                    return InsScreen(
                      children: [
                        _ThreadUnavailableBlock(
                          icon: view.icon,
                          title: view.title,
                          body: view.body,
                          primaryLabel: view.primaryLabel,
                          primaryIcon: view.primaryIcon,
                          onPrimary: view.allowRetry
                              ? () => ref.invalidate(
                                  feedItemDetailProvider(_args),
                                )
                              : () => context.go('/'),
                          onBackHome: () => context.go('/'),
                        ),
                      ],
                    );
                  },
                  data: (item) {
                    if (item == null) {
                      return InsScreen(
                        children: [
                          _ThreadUnavailableBlock(
                            icon: Icons.help_outline_rounded,
                            title: 'This discussion is unavailable',
                            body:
                                'It may have been removed, moved, or is no longer accessible.',
                            primaryLabel: 'Back to home',
                            primaryIcon: Icons.home_outlined,
                            onPrimary: () => context.go('/'),
                            onBackHome: () => context.go('/'),
                          ),
                        ],
                      );
                    }
                    final isOfficial =
                        item.type == FeedItemType.institutionPost &&
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
                            child: AuraLoadingState(
                              message: 'Loading replies…',
                            ),
                          ),
                          error: (e, _) {
                            // Same sanitization as the parent: never leak raw
                            // DioException / minified class names. Replies
                            // failing without parent failing is rare, but we
                            // keep the copy actionable.
                            final view = _ThreadErrorView.fromError(e);
                            return AuraErrorState(
                              title: view.repliesTitle,
                              body: view.repliesBody,
                              action: view.allowRetry
                                  ? AuraSecondaryButton(
                                      label: 'Try again',
                                      icon: Icons.refresh_rounded,
                                      onPressed: () => ref.invalidate(
                                        feedItemRepliesProvider(_args),
                                      ),
                                    )
                                  : null,
                            );
                          },
                          data: (page) {
                            // Phase 6.1 — entry accuracy. Schedule a
                            // post-frame scroll once anchors are mounted.
                            _maybeAutoScroll();
                            // Public-UX Phase 3 — assemble nested reply
                            // tree, accountability timeline, paid-pin.
                            final tree = _buildReplyTree(page.items);
                            final priorityPins = _priorityPinned(tree);
                            final officials = tree
                                .where(_isOfficialReply)
                                .where((r) => !priorityPins.contains(r))
                                .toList(growable: false);
                            final members = tree
                                .where((r) => !_isOfficialReply(r))
                                .where((r) => !priorityPins.contains(r))
                                .toList(growable: false);

                            final showPriority = priorityPins.isNotEmpty;
                            final showOfficials = officials.isNotEmpty;
                            final showMembers =
                                members.isNotEmpty &&
                                _filter == _ReplyFilter.all;

                            if (!showPriority &&
                                !showOfficials &&
                                !showMembers) {
                              return _NoRepliesEmpty(onJoin: _composeReply);
                            }

                            // Build a chronological list of accountability
                            // events for the timeline. Includes only tagged
                            // institutional replies (commitment / update /
                            // resolved); empty list = no timeline rendered.
                            final timeline = _buildTimeline(page.items);

                            // Public-UX Phase 5 — outcome banner at the
                            // very top of the discussion when this thread
                            // already produced a resolution. Distinct from
                            // (and additive to) the timeline below — the
                            // banner is the "headline", the timeline is
                            // the lifecycle.
                            final hasResolution = timeline.any(
                              (e) => e.tag == InsAccountabilityTag.resolved,
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasResolution) ...[
                                  _ResolutionBanner(
                                    actorName: timeline
                                        .lastWhere(
                                          (e) =>
                                              e.tag ==
                                              InsAccountabilityTag.resolved,
                                        )
                                        .actorName,
                                  ),
                                  const SizedBox(height: AuraSpace.s14),
                                ],
                                if (timeline.isNotEmpty) ...[
                                  KeyedSubtree(
                                    key: _timelineKey,
                                    child: _AccountabilityTimeline(
                                      events: timeline,
                                    ),
                                  ),
                                  const SizedBox(height: AuraSpace.s14),
                                ],
                                if (showPriority) ...[
                                  _PriorityPinnedBand(
                                    pinned: priorityPins
                                        .map(
                                          (r) => ReplyWithChildren.from(
                                            r,
                                            _byParent,
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                  if (showOfficials || showMembers)
                                    const SizedBox(height: AuraSpace.s14),
                                ],
                                if (showOfficials) ...[
                                  KeyedSubtree(
                                    key: _firstOfficialKey,
                                    child: _OfficialRepliesBand(
                                      officials: officials,
                                      byParent: _byParent,
                                    ),
                                  ),
                                  if (showMembers)
                                    const SizedBox(height: AuraSpace.s14),
                                ],
                                if (showMembers) ...[
                                  const _SectionLabel(label: 'Member replies'),
                                  const SizedBox(height: AuraSpace.s8),
                                  for (var i = 0; i < members.length; i++) ...[
                                    // Public-UX Phase 6 — "New since you
                                    // last visited" divider before the
                                    // first reply that's newer than the
                                    // cached lastSeenAt. Renders only
                                    // when (a) the cache loaded, (b)
                                    // there IS a previous visit, (c) at
                                    // least one earlier reply existed.
                                    if (_seenLoaded &&
                                        _lastSeenAt != null &&
                                        _isFirstNewReply(members, i)) ...[
                                      const _NewSinceDivider(),
                                      const SizedBox(height: AuraSpace.s10),
                                    ],
                                    // Phase 6.1 — per-reply scroll
                                    // anchor + last-reply marker + new-
                                    // reply fade-in tint for replies
                                    // after _lastSeenAt.
                                    KeyedSubtree(
                                      key: _keyForReply(members[i].id),
                                      child: _NewReplyHighlight(
                                        isNew: _isNewReply(members[i]),
                                        child: i == members.length - 1
                                            ? KeyedSubtree(
                                                key: _lastReplyKey,
                                                child: ReplyUnit(
                                                  reply: members[i],
                                                  parentIsOfficial: isOfficial,
                                                  children:
                                                      _byParent[members[i]
                                                          .id] ??
                                                      const [],
                                                ),
                                              )
                                            : ReplyUnit(
                                                reply: members[i],
                                                parentIsOfficial: isOfficial,
                                                children:
                                                    _byParent[members[i].id] ??
                                                    const [],
                                              ),
                                      ),
                                    ),
                                    if (i < members.length - 1)
                                      const SizedBox(height: AuraSpace.s10),
                                    // Public-UX Phase 5 — inline "What do
                                    // you think?" prompt mid-thread when
                                    // discussion has substance (≥ 3
                                    // member replies above). Shown once
                                    // at the i==2 boundary so it splits
                                    // the rendered list rather than
                                    // appearing repeatedly.
                                    if (i == 2 &&
                                        members.length > 3 &&
                                        i < members.length - 1) ...[
                                      const SizedBox(height: AuraSpace.s12),
                                      _InlineEngagementPrompt(
                                        onTap: _composeReply,
                                      ),
                                      const SizedBox(height: AuraSpace.s12),
                                    ],
                                  ],
                                ],
                                const SizedBox(height: AuraSpace.s14),
                                _JoinDiscussionCue(onTap: _composeReply),
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
              // The composer is part of the same Column as the body Expanded,
              // so it would otherwise render under an error/empty state too.
              // Gate on `canCompose` so a missing/inaccessible thread shows
              // the unavailable block alone — no orphan reply bar.
              if (canCompose) _StickyReplyBar(onTap: _composeReply),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the right reaction target so the existing FeedInteractionBar
  /// works on either user posts or institution posts. Announcements
  /// don't have a reaction endpoint yet — fall back to a user-post
  /// shaped target so callers can still hide the bar by checking the
  /// id; the actual interaction widgets read FeedItem.type and skip.
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
      case FeedItemType.announcement:
        // No announcement-specific reactions surface today. Return a
        // PostReactionTarget so the type contract is satisfied; the
        // unified card already filters announcements out of the
        // interaction bar via _reactionTargetFor()'s null branch.
        return PostReactionTarget(item.id);
    }
  }
}

class _ThreadAppBar extends StatelessWidget {
  const _ThreadAppBar({
    required this.onBack,
    required this.onShare,
    this.followablePostId,
  });

  final VoidCallback onBack;
  final VoidCallback onShare;

  /// When non-null, render the Follow toggle for this thread post id.
  final String? followablePostId;

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
          if (followablePostId != null) ...[
            FollowButton.thread(threadPostId: followablePostId!),
            const SizedBox(width: AuraSpace.s8),
          ],
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
  const _OfficialRepliesBand({
    required this.officials,
    this.byParent = const {},
  });

  final List<FeedReply> officials;
  final Map<String, List<FeedReply>> byParent;

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
              children: byParent[officials[i].id] ?? const [],
            ),
            if (i < officials.length - 1) const SizedBox(height: AuraSpace.s10),
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
          const Icon(Icons.forum_outlined, size: 22, color: AuraSurface.muted),
          const SizedBox(height: AuraSpace.s8),
          const Text('No replies yet — be the first', style: AuraText.subtitle),
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

/// Public-UX Phase 3 — bag carrying a reply alongside its direct
/// children, used by `_PriorityPinnedBand` to drop the children index
/// into a stateless context cleanly.
class ReplyWithChildren {
  const ReplyWithChildren({required this.reply, required this.children});

  final FeedReply reply;
  final List<FeedReply> children;

  static ReplyWithChildren from(
    FeedReply reply,
    Map<String, List<FeedReply>> byParent,
  ) =>
      ReplyWithChildren(reply: reply, children: byParent[reply.id] ?? const []);
}

/// Priority-paid replies pinned to the top of the thread. Renders as
/// a thin bordered band with a "PINNED · PRIORITY · PAID" eyebrow so
/// readers can see immediately that placement was paid for.
class _PriorityPinnedBand extends StatelessWidget {
  const _PriorityPinnedBand({required this.pinned});

  final List<ReplyWithChildren> pinned;

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
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(
          color: AuraSurface.muted.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AuraSpace.s4, bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.push_pin_rounded,
                  size: 12,
                  color: AuraSurface.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  'PINNED',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 6),
                const MonetizationLabel(
                  kind: MonetizationKind.priorityResponse,
                  compact: true,
                ),
              ],
            ),
          ),
          for (var i = 0; i < pinned.length; i++) ...[
            ReplyUnit(
              reply: pinned[i].reply,
              parentIsOfficial: true,
              children: pinned[i].children,
            ),
            if (i < pinned.length - 1) const SizedBox(height: AuraSpace.s10),
          ],
        ],
      ),
    );
  }
}

/// One step in the accountability timeline.
class _TimelineEvent {
  const _TimelineEvent({
    required this.tag,
    required this.actorName,
    required this.replyId,
    this.when,
  });

  final InsAccountabilityTag tag;
  final String actorName;
  final String replyId;
  final DateTime? when;
}

/// Public-UX Phase 3 — accountability timeline.
///
/// Renders a horizontal compressed view of the institutional
/// commitments / updates / resolutions on this thread, oldest first.
/// The timeline answers "did discourse produce an outcome?" without
/// the reader having to scan the whole thread.
class _AccountabilityTimeline extends StatelessWidget {
  const _AccountabilityTimeline({required this.events});

  final List<_TimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timeline_rounded,
                size: 13,
                color: AuraSurface.muted,
              ),
              const SizedBox(width: 5),
              Text(
                'ACCOUNTABILITY TIMELINE',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.faint,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          for (var i = 0; i < events.length; i++) ...[
            _TimelineRow(
              event: events[i],
              isFirst: i == 0,
              isLast: i == events.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final _TimelineEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (Color dot, IconData icon) = switch (event.tag) {
      InsAccountabilityTag.commitment => (
        AuraSurface.accentText,
        Icons.handshake_outlined,
      ),
      InsAccountabilityTag.update => (
        AuraSurface.coSun,
        Icons.update_rounded,
      ),
      InsAccountabilityTag.resolved => (
        AuraSurface.coVerdant,
        Icons.check_circle_outline_rounded,
      ),
    };
    final whenLabel = event.when != null ? formatRelative(event.when!) : '';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical track + dot
          Column(
            children: [
              SizedBox(
                width: 16,
                child: Center(
                  child: SizedBox(
                    width: 1,
                    child: Container(
                      color: isFirst ? Colors.transparent : AuraSurface.divider,
                    ),
                  ),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  border: Border.all(color: AuraSurface.card, width: 1.5),
                ),
                child: Icon(icon, size: 8, color: Colors.white),
              ),
              Expanded(
                child: SizedBox(
                  width: 16,
                  child: Center(
                    child: SizedBox(
                      width: 1,
                      child: Container(
                        color: isLast
                            ? Colors.transparent
                            : AuraSurface.divider,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        event.tag.label.toUpperCase(),
                        style: AuraText.micro.copyWith(
                          color: dot,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                          fontSize: 10,
                        ),
                      ),
                      if (whenLabel.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· $whenLabel',
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.faint,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'by ${event.actorName}',
                    style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Public-UX Phase 6 — "New since you last visited" divider that
/// renders before the first reply newer than the cached last-seen
/// timestamp. Calm — a thin accent line + small label, never a
/// blocky band.
/// Public-UX Phase 6.1 — fade-in tint applied to replies that landed
/// after the cached `_lastSeenAt`. Starts at a soft accent wash and
/// decays to transparent over ~3 seconds so the highlight registers
/// then yields to normal reading.
class _NewReplyHighlight extends StatefulWidget {
  const _NewReplyHighlight({required this.isNew, required this.child});

  final bool isNew;
  final Widget child;

  @override
  State<_NewReplyHighlight> createState() => _NewReplyHighlightState();
}

class _NewReplyHighlightState extends State<_NewReplyHighlight> {
  late bool _showTint = widget.isNew;

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      // Decay the tint shortly after first paint. Single timer per
      // mount; once cleared we never re-tint (changing isNew on an
      // already-mounted reply isn't a real case here).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Future<void>.delayed(const Duration(milliseconds: 2400), () {
          if (!mounted) return;
          setState(() => _showTint = false);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        color: _showTint
            ? AuraSurface.accentSoft.withValues(alpha: 0.55)
            : Colors.transparent,
      ),
      padding: EdgeInsets.all(_showTint ? AuraSpace.s4 : 0),
      child: widget.child,
    );
  }
}

class _NewSinceDivider extends StatelessWidget {
  const _NewSinceDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AuraSurface.accent.withValues(alpha: 0.4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8),
          child: Text(
            'NEW SINCE YOU LAST VISITED',
            style: AuraText.micro.copyWith(
              color: AuraSurface.accentText,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              fontSize: 9,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AuraSurface.accent.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

/// Public-UX Phase 5 — strong banner rendered above the thread content
/// when the discussion has reached a resolution (a RESOLVED-tagged
/// institutional reply exists). Calm but distinct.
class _ResolutionBanner extends StatelessWidget {
  const _ResolutionBanner({required this.actorName});

  final String actorName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s14,
        AuraSpace.s12,
        AuraSpace.s14,
        AuraSpace.s12,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.coVerdant.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(
          color: AuraSurface.coVerdant.withValues(alpha: 0.45),
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: AuraSurface.coVerdant,
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This discussion led to a resolution',
                  style: AuraText.body.copyWith(
                    color: AuraSurface.coVerdant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (actorName.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Resolved by $actorName',
                    style: AuraText.small.copyWith(
                      color: AuraSurface.coVerdant.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Public-UX Phase 5 — inline mid-thread engagement prompt. One tappable
/// row that opens the reply composer for the current thread. Shown
/// exactly once per thread render (after the 3rd member reply) so it
/// splits the list rather than repeating.
class _InlineEngagementPrompt extends StatelessWidget {
  const _InlineEngagementPrompt({required this.onTap});

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
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s10,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AuraRadius.md),
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.forum_rounded,
                size: 14,
                color: AuraSurface.accentText,
              ),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(
                  'What do you think? Add your perspective.',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AuraSurface.accentText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Thread error / unavailable presentation ────────────────────────────────────

/// Maps a Dio/backend error into safe user copy. The previous code dumped
/// `'$e'` into the UI which produced
/// `DioException [bad response]: This could not be found.\nError:
/// Instance of 'minified:pG'` in production. This view object is the
/// single sanitization point for the thread surface; it keeps debug
/// context in logs only.
class _ThreadErrorView {
  const _ThreadErrorView({
    required this.icon,
    required this.title,
    required this.body,
    required this.repliesTitle,
    required this.repliesBody,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.allowRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final String repliesTitle;
  final String repliesBody;
  final String primaryLabel;
  final IconData primaryIcon;
  final bool allowRetry;

  factory _ThreadErrorView.fromError(Object error) {
    int? status;
    if (error is DioException) {
      status = error.response?.statusCode;
    }
    switch (status) {
      case 404:
        return const _ThreadErrorView(
          icon: Icons.help_outline_rounded,
          title: 'This discussion is unavailable',
          body: 'It may have been removed, moved, or is no longer accessible.',
          repliesTitle: 'Replies are unavailable',
          repliesBody:
              'The discussion these replies belonged to is no longer accessible.',
          primaryLabel: 'Back to home',
          primaryIcon: Icons.home_outlined,
          allowRetry: false,
        );
      case 403:
        return const _ThreadErrorView(
          icon: Icons.lock_outline,
          title: 'You do not have access to this discussion',
          body:
              'It may be limited to specific members. Try the conversation context where it was shared.',
          repliesTitle: 'You do not have access to these replies',
          repliesBody:
              'The author or institution has limited who can view this discussion.',
          primaryLabel: 'Back to home',
          primaryIcon: Icons.home_outlined,
          allowRetry: false,
        );
      case 401:
        return const _ThreadErrorView(
          icon: Icons.login_rounded,
          title: 'Sign in to view this discussion',
          body:
              'Your session has ended. Sign in again to continue from where you left off.',
          repliesTitle: 'Sign in to view replies',
          repliesBody: 'Your session has ended.',
          primaryLabel: 'Sign in',
          primaryIcon: Icons.login_rounded,
          allowRetry: false,
        );
      default:
        // Network / 5xx / unknown — actionable retry, no leak.
        return const _ThreadErrorView(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load this discussion',
          body:
              'Check your connection and try again. If the problem continues, return to the home feed.',
          repliesTitle: 'Could not load replies',
          repliesBody: 'Check your connection and try again.',
          primaryLabel: 'Try again',
          primaryIcon: Icons.refresh_rounded,
          allowRetry: true,
        );
    }
  }
}

class _ThreadUnavailableBlock extends StatelessWidget {
  const _ThreadUnavailableBlock({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onBackHome,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AuraSurface.subtle,
                  borderRadius: BorderRadius.circular(AuraRadius.sm),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Icon(icon, size: 16, color: AuraSurface.muted),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(child: Text(title, style: AuraText.title)),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(body, style: AuraText.body.copyWith(height: 1.6)),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              AuraPrimaryButton(
                label: primaryLabel,
                icon: primaryIcon,
                onPressed: onPrimary,
              ),
              if (primaryLabel != 'Back to home')
                AuraGhostButton(label: 'Back to home', onPressed: onBackHome),
            ],
          ),
        ],
      ),
    );
  }
}
