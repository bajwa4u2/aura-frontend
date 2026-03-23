import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
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

  if (inner is Map && inner['data'] is Map) {
    inner = inner['data'];
  }

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
  if (directItem is Map) {
    return _PinnedAnnouncement.tryFrom(directItem);
  }

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

final latestHeldProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/held/latest');
  final raw = res.data;

  final root = _asMap(raw);
  final topHeld = root['item'] ?? root['draft'];
  if (topHeld is Map) return Map<String, dynamic>.from(topHeld);

  final m = _unwrapMap(raw);
  final innerHeld = m['item'] ?? m['draft'];
  if (innerHeld is Map) return Map<String, dynamic>.from(innerHeld);

  if (m.isNotEmpty && (m['id'] != null || m['text'] != null)) {
    return m;
  }

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
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s12,
                AuraSpace.s16,
                AuraSpace.s28,
              ),
              children: [
                const _PinnedAnnouncementBanner(),
                const SizedBox(height: AuraSpace.s16),
                heldAsync.when(
                  data: (held) {
                    final heldMap = _asMap(held);
                    final hasHeld = heldMap.isNotEmpty;
                    final heldId = heldMap['id']?.toString();

                    return _ComposerEntryCard(
                      hasHeld: hasHeld,
                      heldText: heldMap['text']?.toString(),
                      onTap: () => _openCompose(context, ref, heldId: heldId),
                    );
                  },
                  loading: () => _ComposerEntryCard(
                    hasHeld: false,
                    onTap: () => _openCompose(context, ref),
                  ),
                  error: (_, __) => _ComposerEntryCard(
                    hasHeld: false,
                    onTap: () => _openCompose(context, ref),
                  ),
                ),
                const SizedBox(height: AuraSpace.s24),
                if (feedState.isLoading && feedState.items.isEmpty)
                  const _LoadingCard()
                else if (feedState.error != null && feedState.items.isEmpty)
                  AuraCard(
                    child: Text(
                      'Could not load works.',
                      style: AuraText.body,
                    ),
                  )
                else if (feedState.items.isEmpty)
                  const _EmptyWorksCard()
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Works',
                        subtitle: '${feedState.items.length} in view',
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: feedState.items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AuraSpace.s18),
                        itemBuilder: (context, i) {
                          return PostCard(post: feedState.items[i]);
                        },
                      ),
                      const SizedBox(height: AuraSpace.s20),
                      if (feedState.isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.only(top: AuraSpace.s4),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      if (feedState.nextCursor != null &&
                          feedState.nextCursor!.trim().isNotEmpty &&
                          !feedState.isLoadingMore) ...[
                        const SizedBox(height: AuraSpace.s4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              ref
                                  .read(feedControllerProvider.notifier)
                                  .loadMore();
                            },
                            child: const Text('Load more'),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerEntryCard extends StatelessWidget {
  const _ComposerEntryCard({
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
    if (text.length <= 140) return text;
    return '${text.substring(0, 140).trim()}…';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview(heldText ?? '');

    return AuraCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasHeld ? 'Continue where you left' : 'New work',
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            hasHeld
                ? 'Return to the latest work you are holding.'
                : 'Start a new work.',
            style: AuraText.body,
          ),
          if (hasHeld && preview.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Text(
              preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AuraText.small.copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _PinnedAnnouncementBanner extends ConsumerWidget {
  const _PinnedAnnouncementBanner();

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
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

        return AuraCard(
          onTap: () => context.push('/announcements/${a.slug}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign_outlined, size: 18),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(
                    child: Text(
                      'Pinned announcement',
                      style: AuraText.small.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: AuraSpace.s10),
              Text(
                title,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
              ),
              if (a.publishedAt != null) ...[
                const SizedBox(height: AuraSpace.s6),
                Text(
                  'Published: ${_fmt(a.publishedAt!)}',
                  style: AuraText.small,
                ),
              ],
              if (summary.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s10),
                Text(summary, style: AuraText.body),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          subtitle,
          style: AuraText.small,
        ),
      ],
    );
  }
}

class _EmptyWorksCard extends StatelessWidget {
  const _EmptyWorksCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Text(
        'No works yet.',
        style: AuraText.body,
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
