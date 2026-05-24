import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';

import '../../../app/shell/rail/rail_composition.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/surface/surface_composition.dart';

import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../institutions/live_rooms/global_live_discovery.dart';
import '../../institutions/live_rooms/live_now_card.dart';
import '../../public/widgets/activation_overlay.dart';
import '../../public/widgets/discourse_card.dart';
import '../../public/widgets/public_composer.dart';
import '../../public/widgets/since_you_were_here.dart';
import '../../public/widgets/space_card.dart';

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapMap(dynamic raw) {
  final root = _asMap(raw);
  dynamic inner = root['data'];
  if (inner is Map && inner['data'] is Map) inner = inner['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return root;
}

class _PinnedAnnouncement {
  const _PinnedAnnouncement({
    required this.slug,
    required this.title,
    required this.summary,
    required this.publishedAt,
  });

  final String slug;
  final String title;
  final String summary;
  final DateTime? publishedAt;

  static _PinnedAnnouncement? tryFrom(dynamic raw) {
    final m = _asMap(raw);
    if (m.isEmpty) return null;
    final slug = (m['slug'] ?? '').toString().trim();
    if (slug.isEmpty) return null;
    final title = (m['title'] ?? slug).toString().trim();
    final summary = (m['summary'] ?? m['excerpt'] ?? '').toString().trim();
    DateTime? publishedAt;
    final p = m['publishedAt'];
    if (p is String && p.trim().isNotEmpty) {
      publishedAt = DateTime.tryParse(p.trim());
    }
    return _PinnedAnnouncement(
      slug: slug,
      title: title.isEmpty ? slug : title,
      summary: summary,
      publishedAt: publishedAt,
    );
  }
}

_PinnedAnnouncement? _unwrapPinned(dynamic raw) {
  final root = _asMap(raw);
  final directItem = root['item'];
  if (directItem is Map) return _PinnedAnnouncement.tryFrom(directItem);
  final directItems = root['items'];
  if (directItems is List) {
    for (final it in directItems) {
      final a = _PinnedAnnouncement.tryFrom(it);
      if (a != null) return a;
    }
  }
  final data = root['data'];
  if (data is Map) {
    final item = data['item'];
    if (item is Map) return _PinnedAnnouncement.tryFrom(item);
    final items = data['items'];
    if (items is List) {
      for (final it in items) {
        final a = _PinnedAnnouncement.tryFrom(it);
        if (a != null) return a;
      }
    }
    final inner = data['data'];
    if (inner is Map) {
      final innerItem = inner['item'];
      if (innerItem is Map) return _PinnedAnnouncement.tryFrom(innerItem);
      final innerItems = inner['items'];
      if (innerItems is List) {
        for (final it in innerItems) {
          final a = _PinnedAnnouncement.tryFrom(it);
          if (a != null) return a;
        }
      }
    }
  }
  final m = _unwrapMap(raw);
  return _PinnedAnnouncement.tryFrom(m);
}

final pinnedAnnouncementProvider =
    FutureProvider.autoDispose<_PinnedAnnouncement?>((ref) async {
      final dio = ref.watch(dioProvider);
      final res = await dio.get('/announcements/pinned');
      return _unwrapPinned(res.data);
    });

final latestHeldProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/held/latest');
  final raw = res.data;
  final root = _asMap(raw);
  final topHeld = root['item'] ?? root['draft'];
  if (topHeld is Map) return Map<String, dynamic>.from(topHeld);
  final m = _unwrapMap(raw);
  final innerHeld = m['item'] ?? m['draft'];
  if (innerHeld is Map) return Map<String, dynamic>.from(innerHeld);
  if (m.isNotEmpty && (m['id'] != null || m['text'] != null)) return m;
  return null;
});

class MemberHomeScreen extends ConsumerStatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  ConsumerState<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends ConsumerState<MemberHomeScreen> {
  bool _activationChecked = false;

  Future<void> _openCompose({String? heldId}) async {
    final target = (heldId ?? '').trim().isNotEmpty
        ? '/compose?held=${Uri.encodeComponent(heldId!.trim())}'
        : '/compose';
    await context.push(target);
    ref.invalidate(latestHeldProvider);
  }

  Future<void> _refresh() async {
    ref.invalidate(latestHeldProvider);
    ref.invalidate(pinnedAnnouncementProvider);
    // Phase 3 — pull-to-refresh resets the paged feed back to page 1.
    await ref.read(memberHomeFeedPagedProvider.notifier).refresh();
  }

  Future<void> _maybeShowActivationOverlay() async {
    if (_activationChecked) return;
    _activationChecked = true;
    final shouldShow = await ActivationOverlay.shouldShow();
    if (!shouldShow || !mounted) return;
    // Defer one frame so the home renders behind the overlay first.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const ActivationOverlay(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);
    if (isAuthed) {
      // Schedule the activation overlay check after build. Only fires
      // once per device (SharedPreferences-backed inside the overlay).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowActivationOverlay();
      });
    }
    final heldAsync = isAuthed
        ? ref.watch(latestHeldProvider)
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    // Member home — wrapped in AuraSurfaceScaffold so the desktop right
    // rail composes alongside the discourse feed. The scaffold's
    // `discourseFeed` policy renders the context rail only at desktop
    // (≥1200), so on tablet/mobile the layout collapses to a single
    // column without any extra branching here. Rail modules are
    // provider-backed and self-hide when their source has nothing to
    // surface.
    //
    // Desktop density pass: the rhythm between hero sections and the
    // adaptive `maxContentWidth` (via the policy override below) are
    // tuned so wide desktops and ultrawide monitors do not waste
    // horizontal real estate to dead margins. Standard 1200–1439 px
    // desktops keep `kFeedWidth = 1100` for reading comfort; ≥1440
    // grows to 1200; ≥1680 grows to 1280 (matches workspace width).
    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final policy = _adaptiveDiscourseFeedPolicy(constraints.maxWidth);
            return AuraSurfaceScaffold(
              type: AuraSurfaceType.discourseFeed,
              policy: policy,
              center: ListView(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  // Tightened from s20 → s12. The shell + context bar
                  // already mark the top; an additional 20 px of body
                  // padding pushed content unnecessarily low. 12 px
                  // still gives visual breathing room without dead
                  // space at the top of the discourse feed.
                  AuraSpace.s12,
                  0,
                  AuraSpace.s32,
                ),
                children: [
                  // ── Pinned announcement (silent if absent)
                  const _PinnedAnnouncementBanner(),

                  // ── Public-UX Phase 6: re-entry "Since you were here"
                  // Renders only when there are unread, recent,
                  // discourse-relevant notifications. Collapsible.
                  const SinceYouWereHereSection(),
                  const SizedBox(height: AuraSpace.s8),

                  // ── Public composer (primary discourse entry)
                  const PublicComposer(),

                  // ── Held-draft hint (only renders when a draft is in
                  // play); single tap routes back into the compose flow
                  // with the held id pre-loaded.
                  heldAsync.when(
                    data: (held) {
                      final heldMap = _asMap(held);
                      if (heldMap.isEmpty) return const SizedBox.shrink();
                      final heldId = heldMap['id']?.toString();
                      return Padding(
                        padding: const EdgeInsets.only(top: AuraSpace.s6),
                        child: _HeldDraftHint(
                          text: heldMap['text']?.toString(),
                          onTap: () => _openCompose(heldId: heldId),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // Section gap from composer → spaces tightened from
                  // s20 → s14. The composer is a single card; 14 px
                  // is enough boundary without feeling sectionally
                  // disconnected.
                  const SizedBox(height: AuraSpace.s14),

                  // ── Spaces — promoted near the composer so discovery is not
                  // buried at the bottom of the discourse stream. Renders as
                  // a multi-column grid on tablet/desktop via AdaptiveCardGrid
                  // and falls back to a pointer-aware horizontal rail on
                  // narrow viewports (mouse-wheel + arrow keys + chevrons).
                  const _SpacesSection(),

                  // Section gap from spaces → discourse stream tightened
                  // from s24 → s16. The spaces section ends with its
                  // own cards; 16 px reads as "next section" without
                  // a yawning gap.
                  const SizedBox(height: AuraSpace.s16),

                  // ── Discourse stream + LIVE NOW
                  const _DiscourseStream(),
                ],
              ),
              // Provider-backed contextual modules. Each module
              // self-hides when its source has no data, so the rail
              // collapses gracefully on quiet days. Order is visual
              // priority: time-sensitive (Live, Recent activity,
              // Pinned) above discovery (Verified institutions) and
              // longer-running affordances (Saved) and grounding
              // (Governance). Rail composition lives in
              // rail_composition.dart — one source of truth for what
              // each shell stacks and in what priority order.
              contextRail: AuraContextRail(modules: memberFeedRailModules()),
            );
          },
        ),
      ),
    );
  }
}

/// Adaptive policy override for the member discourse feed. Standard
/// desktop keeps `kFeedWidth = 1100` for reading comfort; wider
/// viewports lift the cap so the center column doesn't waste the
/// horizontal canvas to dead margins next to the right rail.
///
/// The width override is the only field that changes — every other
/// field comes from `AuraSurfacePolicy.forType(discourseFeed)`, so we
/// don't fork the surface contract.
AuraSurfacePolicy _adaptiveDiscourseFeedPolicy(double viewportWidth) {
  final base = AuraSurfacePolicy.forType(AuraSurfaceType.discourseFeed);
  double width = base.maxContentWidth;
  if (viewportWidth >= 1680) {
    width = 1280;
  } else if (viewportWidth >= 1440) {
    width = 1200;
  }
  if (width == base.maxContentWidth) return base;
  return AuraSurfacePolicy(
    maxContentWidth: width,
    composition: base.composition,
    leftRailVisibility: base.leftRailVisibility,
    contextRailVisibility: base.contextRailVisibility,
    density: base.density,
    bodyHorizontalPadding: base.bodyHorizontalPadding,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PINNED ANNOUNCEMENT BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedAnnouncementBanner extends ConsumerWidget {
  const _PinnedAnnouncementBanner();

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pinnedAnnouncementProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (a) {
        if (a == null) return const SizedBox.shrink();
        final title = a.title.trim().isEmpty ? a.slug : a.title.trim();
        final summary = a.summary.trim();

        return Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s16),
          child: AuraCard(
            onTap: () => context.push('/announcements/${a.slug}'),
            borderColor: AuraSurface.coSun.withValues(alpha: 0.2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AuraSurface.coSun.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AuraRadius.r10),
                    border: Border.all(
                      color: AuraSurface.coSun.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.push_pin_outlined,
                    size: 16,
                    color: AuraSurface.coSun,
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pinned announcement',
                            style: AuraText.label.copyWith(
                              color: AuraSurface.coSun,
                            ),
                          ),
                          const Spacer(),
                          if (a.publishedAt != null)
                            Text(_fmt(a.publishedAt!), style: AuraText.micro),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s6),
                      Text(
                        title,
                        style: AuraText.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AuraSurface.ink,
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s4),
                        Text(
                          summary,
                          style: AuraText.small,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AuraSpace.s8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AuraSurface.faint,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WORKS SECTION WITH SORT TOGGLE
// ─────────────────────────────────────────────────────────────────────────────

/// Member Home "Works" feed — backed by the unified
/// `memberHomeFeedPagedProvider` (`GET /v1/feed/member`). Renders both
/// user posts and globally-eligible institution posts with
/// `UnifiedFeedCard`. Phase 3 restored cursor pagination — a "Load more"
/// button at the bottom of the feed advances through pages without
/// duplicates (the paged notifier de-dupes by `(type, id)`).
class _DiscourseStream extends ConsumerWidget {
  const _DiscourseStream();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(memberHomeFeedPagedProvider);
    // Phase 2 Distribution — surface up to 3 active institution live
    // sessions at the top of the member home feed. Reuses the same
    // shared `LiveNowCard` used by the institution explore feed and
    // the public home feed. Hidden silently when none.
    final liveAsync = ref.watch(globalDiscoverableLiveProvider);

    return feedAsync.when(
      loading: () => const Column(
        children: [
          AuraCardSkeleton(),
          SizedBox(height: AuraSpace.s10),
          AuraCardSkeleton(),
        ],
      ),
      error: (e, _) => AuraErrorState(
        title: 'Could not load works',
        body: 'Refresh or try again in a moment.',
        action: AuraSecondaryButton(
          label: 'Refresh',
          onPressed: () =>
              ref.read(memberHomeFeedPagedProvider.notifier).refresh(),
          icon: Icons.refresh_rounded,
        ),
      ),
      data: (page) {
        final liveEntries = liveAsync.maybeWhen(
          data: (entries) => entries,
          orElse: () => const <LiveNowDiscoveryEntry>[],
        );
        if (page.items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Even with no works, show LIVE NOW + spaces strip so
              // the home doesn't feel dead and the user has somewhere
              // to enter discourse from.
              if (liveEntries.isNotEmpty) ...[
                const _SectionTitle(
                  title: 'Live now',
                  subtitle: 'Sessions happening this moment.',
                ),
                const SizedBox(height: AuraSpace.s10),
                for (final e in liveEntries) ...[
                  LiveNowCard(
                    data: LiveNowCardData.fromDiscovery(
                      entry: e,
                      returnTo: '/home',
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s10),
                ],
                const SizedBox(height: AuraSpace.s14),
              ],
              const AuraEmptyState(
                title: 'Quiet on the public stream right now',
                body:
                    'When people publish, their statements will appear here.',
                icon: Icons.forum_outlined,
              ),
              // Spaces is rendered earlier in the feed (above _DiscourseStream)
              // so we no longer also stamp it in the empty-state column. Keeping
              // it here would double-render the same section.
            ],
          );
        }
        // Phase 2 — group items by activity:
        //   * Active discussions: items with replies or recent activity.
        //   * Institutional voices: items authored by institutions OR
        //     where institutions have responded.
        //   * Recent statements: everything else, in original order.
        // An item appears in at most one band — the strongest one — so
        // we never show the same statement twice.
        final byBand = _bandItems(page.items);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (liveEntries.isNotEmpty) ...[
              const _SectionTitle(
                title: 'Live now',
                subtitle: 'Sessions happening this moment.',
              ),
              const SizedBox(height: AuraSpace.s10),
              for (final e in liveEntries) ...[
                LiveNowCard(
                  data: LiveNowCardData.fromDiscovery(
                    entry: e,
                    returnTo: '/home',
                  ),
                ),
                const SizedBox(height: AuraSpace.s10),
              ],
              const SizedBox(height: AuraSpace.s18),
            ],
            if (byBand.activeDiscussions.isNotEmpty) ...[
              const _SectionTitle(
                title: 'Active discussions',
                subtitle: 'People are responding now.',
              ),
              const SizedBox(height: AuraSpace.s10),
              for (var i = 0;
                  i < byBand.activeDiscussions.length;
                  i++) ...[
                DiscourseCard(item: byBand.activeDiscussions[i]),
                if (i < byBand.activeDiscussions.length - 1)
                  const SizedBox(height: AuraSpace.s12),
              ],
              const SizedBox(height: AuraSpace.s18),
            ],
            if (byBand.institutional.isNotEmpty) ...[
              const _SectionTitle(
                title: 'Institutional voices',
                subtitle:
                    'Verified institutions speaking and responding.',
              ),
              const SizedBox(height: AuraSpace.s10),
              for (var i = 0; i < byBand.institutional.length; i++) ...[
                DiscourseCard(item: byBand.institutional[i]),
                if (i < byBand.institutional.length - 1)
                  const SizedBox(height: AuraSpace.s12),
              ],
              const SizedBox(height: AuraSpace.s18),
            ],
            if (byBand.recent.isNotEmpty) ...[
              const _SectionTitle(
                title: 'Recent statements',
                subtitle: 'Everything else, in order.',
              ),
              const SizedBox(height: AuraSpace.s10),
              for (var i = 0; i < byBand.recent.length; i++) ...[
                DiscourseCard(item: byBand.recent[i]),
                if (i < byBand.recent.length - 1)
                  const SizedBox(height: AuraSpace.s12),
              ],
              const SizedBox(height: AuraSpace.s18),
            ],
            // Phase 3 — cursor-driven Load more.
            if (page.hasMore) ...[
              Center(
                child: AuraSecondaryButton(
                  label: page.loadingMore ? 'Loading…' : 'Load more',
                  icon: page.loadingMore
                      ? Icons.hourglass_empty_rounded
                      : Icons.expand_more_rounded,
                  onPressed: page.loadingMore
                      ? null
                      : () => ref
                          .read(memberHomeFeedPagedProvider.notifier)
                          .loadMore(),
                ),
              ),
              const SizedBox(height: AuraSpace.s18),
            ],
            // Spaces is promoted to the top of the feed (rendered in
            // MemberHomeScreen, above _DiscourseStream); removed from the
            // bottom of the discourse stream to avoid double-rendering.
          ],
        );
      },
    );
  }

  /// Group items into bands by activity. Each item appears in at most
  /// one band — the strongest one wins. Order within each band is the
  /// original feed order so backend sort is preserved as the
  /// tiebreaker.
  _BandedItems _bandItems(List<FeedItem> all) {
    final active = <FeedItem>[];
    final institutional = <FeedItem>[];
    final recent = <FeedItem>[];
    for (final item in all) {
      if (_isActive(item)) {
        active.add(item);
      } else if (_isInstitutionalVoice(item)) {
        institutional.add(item);
      } else {
        recent.add(item);
      }
    }
    return _BandedItems(
      activeDiscussions: active,
      institutional: institutional,
      recent: recent,
    );
  }

  bool _isActive(FeedItem item) {
    final inter = item.interaction;
    final hasMomentum =
        inter.canViewReplyCount && inter.replyCount >= 2;
    return hasMomentum || item.activity?.recentReply == true;
  }

  bool _isInstitutionalVoice(FeedItem item) {
    if (item.type == FeedItemType.institutionPost) return true;
    final preview = item.replyPreview;
    if (preview == null) return false;
    return preview.items.any((r) =>
        r.author.context?.type ==
        FeedIdentityContextType.officialInstitution);
  }
}

/// Three-band item grouping for the discourse stream.
class _BandedItems {
  const _BandedItems({
    required this.activeDiscussions,
    required this.institutional,
    required this.recent,
  });

  final List<FeedItem> activeDiscussions;
  final List<FeedItem> institutional;
  final List<FeedItem> recent;
}

/// Stronger section title — heading + one-line subtitle. Anchors each
/// activity band so the home doesn't read as a flat content list.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.subtitle),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Spaces strip section — heading + horizontal scroll of curated
/// public-discourse spaces. Backend doesn't yet expose a public spaces
/// endpoint; until it does, the strip ships with calibrated topical
/// seeds (civic / climate / tech / education / health / local) routed
/// through the existing /search surface.
class _SpacesSection extends StatelessWidget {
  const _SpacesSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spaces', style: AuraText.subtitle),
        SizedBox(height: AuraSpace.s4),
        Text(
          'Topical and regional discourse environments. Public-first.',
          style: AuraText.muted,
        ),
        SizedBox(height: AuraSpace.s12),
        PublicSpacesStrip(),
      ],
    );
  }
}

/// Compact "you have a held draft" hint rendered beneath the public
/// composer. Single tap re-enters the compose flow with the held id
/// pre-loaded so the user can resume.
class _HeldDraftHint extends StatelessWidget {
  const _HeldDraftHint({required this.text, required this.onTap});

  final String? text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = (text ?? '').trim();
    return InkWell(
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
              Icons.edit_note_rounded,
              size: 14,
              color: AuraSurface.muted,
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                preview.isNotEmpty
                    ? 'Resume your draft: ${preview.length > 60 ? '${preview.substring(0, 60)}…' : preview}'
                    : 'You have an unfinished draft.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AuraSurface.faint,
            ),
          ],
        ),
      ),
    );
  }
}

