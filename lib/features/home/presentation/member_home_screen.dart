import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

import '../../feed/providers.dart';
import '../../posts/presentation/widgets/post_card.dart';

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
    await ref.read(feedControllerProvider.notifier).loadInitial();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthedProvider);
    final feedState = ref.watch(feedControllerProvider);

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

                // ── Composer entry card
                heldAsync.when(
                  data: (held) {
                    final heldMap = _asMap(held);
                    final hasHeld = heldMap.isNotEmpty;
                    final heldId = heldMap['id']?.toString();
                    return _ComposerCard(
                      hasHeld: hasHeld,
                      heldText: heldMap['text']?.toString(),
                      onTap: () => _openCompose(context, ref, heldId: heldId),
                    );
                  },
                  loading: () => const AuraCardSkeleton(),
                  error: (_, __) => _ComposerCard(
                    hasHeld: false,
                    onTap: () => _openCompose(context, ref),
                  ),
                ),

                const SizedBox(height: AuraSpace.s28),

                // ── Feed
                if (feedState.isLoading && feedState.items.isEmpty) ...[
                  const AuraCardSkeleton(),
                  const SizedBox(height: AuraSpace.s10),
                  const AuraCardSkeleton(),
                ] else if (feedState.error != null &&
                    feedState.items.isEmpty) ...[
                  AuraErrorState(
                    title: 'Could not load works',
                    body: 'Refresh or try again in a moment.',
                    action: AuraSecondaryButton(
                      label: 'Refresh',
                      onPressed: () => ref
                          .read(feedControllerProvider.notifier)
                          .loadInitial(),
                      icon: Icons.refresh_rounded,
                    ),
                  ),
                ] else if (feedState.items.isEmpty) ...[
                  const AuraEmptyState(
                    title: 'No works yet',
                    body: 'When you publish, your work will appear here.',
                    icon: Icons.auto_stories_outlined,
                  ),
                ] else ...[
                  // Section label
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Works', style: AuraText.subtitle),
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
                          '${feedState.items.length}',
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.faint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s14),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: feedState.items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AuraSpace.s14),
                    itemBuilder: (context, i) =>
                        PostCard(post: feedState.items[i]),
                  ),
                  const SizedBox(height: AuraSpace.s20),
                  if (feedState.isLoadingMore)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AuraSurface.muted,
                        ),
                      ),
                    ),
                  if (feedState.nextCursor != null &&
                      feedState.nextCursor!.trim().isNotEmpty &&
                      !feedState.isLoadingMore)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AuraGhostButton(
                        label: 'Load more',
                        onPressed: () => ref
                            .read(feedControllerProvider.notifier)
                            .loadMore(),
                        icon: Icons.expand_more_rounded,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSER ENTRY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.hasHeld,
    required this.onTap,
    this.heldText,
  });

  final bool hasHeld;
  final String? heldText;
  final VoidCallback onTap;

  String _preview(String value) {
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';
    if (text.length <= 160) return text;
    return '${text.substring(0, 160).trim()}…';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview(heldText ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF172444), Color(0xFF0F1E36)],
            ),
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.25),
            ),
            boxShadow: AuraShadows.panel,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent top stripe
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: AuraGradients.accent,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AuraRadius.card),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s20,
                  AuraSpace.s18,
                  AuraSpace.s20,
                  AuraSpace.s20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.s8,
                            vertical: AuraSpace.s4,
                          ),
                          decoration: BoxDecoration(
                            color: AuraSurface.accentSoft,
                            borderRadius: BorderRadius.circular(
                              AuraRadius.pill,
                            ),
                            border: Border.all(
                              color: AuraSurface.accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit_outlined,
                                size: 11,
                                color: AuraSurface.accentText,
                              ),
                              const SizedBox(width: AuraSpace.s4),
                              Text(
                                hasHeld ? 'Held work' : 'Composer',
                                style: AuraText.label.copyWith(
                                  color: AuraSurface.accentText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AuraSurface.faint,
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    Text(
                      hasHeld
                          ? 'Continue your held work'
                          : 'Start something new',
                      style: AuraText.headline,
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      hasHeld
                          ? 'You have a work in progress. Return to the editing surface.'
                          : 'Begin a new piece — writing, media, or long-form work.',
                      style: AuraText.body.copyWith(color: AuraSurface.muted),
                    ),
                    if (hasHeld && preview.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s14),
                      Container(
                        padding: const EdgeInsets.all(AuraSpace.s12),
                        decoration: BoxDecoration(
                          color: AuraSurface.page.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AuraRadius.r12),
                          border: Border.all(color: AuraSurface.divider),
                        ),
                        child: Text(
                          preview,
                          style: AuraText.small.copyWith(
                            height: 1.5,
                            color: AuraSurface.muted,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
