import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/post.dart';
import '../../feed/providers.dart';

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

class PublicHomeScreen extends ConsumerWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return AuraScaffold(
      title: 'Aura',
      actions: const [],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          final pinnedAsync = ref.watch(pinnedAnnouncementProvider);
          final pinnedBanner = pinnedAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (a) =>
                a == null ? const SizedBox.shrink() : _PinnedAnnouncementBanner(a: a),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: [
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _PublicHero(),
                          const SizedBox(height: AuraSpace.s12),
                          pinnedBanner,
                        ],
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s16),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: const _EntryStack(),
                      ),
                    ),
                  ],
                )
              else ...[
                const _PublicHero(),
                const SizedBox(height: AuraSpace.s12),
                pinnedBanner,
                const SizedBox(height: AuraSpace.s14),
                const _EntryStack(),
              ],
              const SizedBox(height: AuraSpace.s20),
              _SectionHeader(
                title: 'Public record',
                subtitle: 'Approved public posts.',
                actionLabel: 'Explore',
                onAction: () => context.go('/search'),
              ),
              const SizedBox(height: AuraSpace.s12),
              feedAsync.when(
                data: (posts) {
                  if (posts.isEmpty) {
                    return const AuraCard(
                      child: Text(
                        'No public posts yet.',
                        style: AuraText.body,
                      ),
                    );
                  }

                  final show = posts.take(6).toList();

                  return Column(
                    children: [
                      for (final p in show) ...[
                        _PublicPostPreview(post: p),
                        const SizedBox(height: AuraSpace.s10),
                      ],
                      const SizedBox(height: AuraSpace.s6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => context.go('/search'),
                          child: const Text('See more'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(
                  child: Text(
                    'Could not load public feed yet. ($e)',
                    style: AuraText.body,
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s24),
            ],
          );
        },
      ),
    );
  }
}

class _EntryStack extends StatelessWidget {
  const _EntryStack();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PublicAuthPanel(),
        SizedBox(height: AuraSpace.s14),
        _InstitutionEntryCard(),
      ],
    );
  }
}

class _PublicAuthPanel extends StatelessWidget {
  const _PublicAuthPanel();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enter as member', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/register?redirect=%2Fhome'),
              child: const Text('Create member account'),
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/login?redirect=%2Fhome'),
              child: const Text('Member sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionEntryCard extends StatelessWidget {
  const _InstitutionEntryCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enter as institution', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),

          /// All institutional access flows must pass through
          /// the institutional gateway so the system can determine
          /// the correct state (public / no standing / verified / speaker).

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/enter-institution'),
              child: const Text('Create institution account'),
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/enter-institution'),
              child: const Text('Institution sign in'),
            ),
          ),
        ],
      ),
    );
  }
}