import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

import '../../feed/data/unified_feed_providers.dart';
import '../../institutions/live_rooms/global_live_discovery.dart';
import '../../institutions/live_rooms/live_now_card.dart';
import '../../public/widgets/discourse_card.dart';
import '../../public/widgets/public_composer.dart';
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

class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  Future<void> _openCompose(
    BuildContext context,
    WidgetRef ref, {
    String? heldId,
  }) async {
    final target = (heldId ?? '').trim().isNotEmpty
        ? '/compose?held=${Uri.encodeComponent(heldId!.trim())}'
        : '/compose';
    await context.push(target);
    ref.invalidate(latestHeldProvider);
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(latestHeldProvider);
    ref.invalidate(pinnedAnnouncementProvider);
    ref.invalidate(memberHomeFeedProvider);
    await ref.read(memberHomeFeedProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthedProvider);
    final heldAsync = isAuthed
        ? ref.watch(latestHeldProvider)
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              children: [
                // ── Pinned announcement (silent if absent)
                const _PinnedAnnouncementBanner(),

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
                      padding: const EdgeInsets.only(top: AuraSpace.s8),
                      child: _HeldDraftHint(
                        text: heldMap['text']?.toString(),
                        onTap: () =>
                            _openCompose(context, ref, heldId: heldId),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: AuraSpace.s24),

                // ── Discourse stream + LIVE NOW + spaces strip
                const _DiscourseStream(),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
            borderColor: AuraSurface.warnInk.withValues(alpha: 0.2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AuraSurface.warnBg,
                    borderRadius: BorderRadius.circular(AuraRadius.r10),
                    border: Border.all(
                      color: AuraSurface.warnInk.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.push_pin_outlined,
                    size: 16,
                    color: AuraSurface.warnInk,
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
                              color: AuraSurface.warnInk,
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

/// Member Home "Works" feed — backed by the unified `memberHomeFeedProvider`
/// (`GET /v1/feed/member`). Renders both user posts and globally-eligible
/// institution posts with `UnifiedFeedCard`. Pagination beyond the first
/// page is intentionally deferred to a follow-up phase — the legacy
/// `feedControllerProvider` paging machinery was removed in this migration.
class _DiscourseStream extends ConsumerWidget {
  const _DiscourseStream();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(memberHomeFeedProvider);
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
          onPressed: () => ref.invalidate(memberHomeFeedProvider),
          icon: Icons.refresh_rounded,
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Even with no works, show LIVE NOW + spaces strip so
              // the home doesn't feel dead and the user has somewhere
              // to enter discourse from.
              ...liveAsync.maybeWhen(
                data: (entries) => [
                  for (final e in entries) ...[
                    LiveNowCard(
                      data: LiveNowCardData.fromDiscovery(
                        entry: e,
                        returnTo: '/home',
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                ],
                orElse: () => const <Widget>[],
              ),
              const AuraEmptyState(
                title: 'Quiet on the public stream right now',
                body:
                    'When people publish, their statements will appear here.',
                icon: Icons.forum_outlined,
              ),
              const SizedBox(height: AuraSpace.s24),
              const _SpacesSection(),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live first — it's "happening now".
            ...liveAsync.maybeWhen(
              data: (entries) => [
                for (final e in entries) ...[
                  LiveNowCard(
                    data: LiveNowCardData.fromDiscovery(
                      entry: e,
                      returnTo: '/home',
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s10),
                ],
              ],
              orElse: () => const <Widget>[],
            ),
            // Section header — discourse, not "works".
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Discourse', style: AuraText.subtitle),
                const SizedBox(width: AuraSpace.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s8,
                    vertical: AuraSpace.s2,
                  ),
                  decoration: BoxDecoration(
                    color: AuraSurface.subtle,
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                  ),
                  child: Text(
                    '${page.items.length}',
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: page.items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AuraSpace.s14),
              itemBuilder: (context, i) =>
                  DiscourseCard(item: page.items[i]),
            ),
            const SizedBox(height: AuraSpace.s24),
            const _SpacesSection(),
          ],
        );
      },
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

