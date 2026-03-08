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

class _PinnedAnnouncementBanner extends StatelessWidget {
  const _PinnedAnnouncementBanner({required this.a});
  final _PinnedAnnouncement a;

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                  style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AuraSurface.muted),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w800)),
          if (a.publishedAt != null) ...[
            const SizedBox(height: AuraSpace.s6),
            Text('Published: ${_fmt(a.publishedAt!)}', style: AuraText.small),
          ],
          if (summary.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(summary, style: AuraText.body),
          ],
        ],
      ),
    );
  }
}

class _PublicHero extends StatelessWidget {
  const _PublicHero();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A civic layer for accountable public writing.',
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'For members and institutions.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              _Pill(
                label: 'Mission',
                icon: Icons.flag_outlined,
                onTap: () => context.go('/mission'),
              ),
              _Pill(
                label: 'Founder',
                icon: Icons.person_outline,
                onTap: () => context.go('/founder'),
              ),
              _Pill(
                label: 'Institutions',
                icon: Icons.apartment_outlined,
                onTap: () => context.go('/institutions'),
              ),
              _Pill(
                label: 'Investors',
                icon: Icons.assured_workload_outlined,
                onTap: () => context.go('/investors'),
              ),
              _Pill(
                label: 'Contact',
                icon: Icons.mail_outline,
                onTap: () => context.go('/contact'),
              ),
              _Pill(
                label: 'Search',
                icon: Icons.search,
                onTap: () => context.go('/search'),
              ),
            ],
          ),
        ],
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/institution/sign-in'),
              child: const Text('Institution sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AuraText.title),
              const SizedBox(height: AuraSpace.s8),
              Text(subtitle, style: AuraText.muted),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: AuraSpace.s12),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _PublicPostPreview extends StatelessWidget {
  const _PublicPostPreview({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    final name = (a?.displayName ?? '').trim();
    final handle = (a?.handle ?? '').trim();
    final byline =
        handle.isEmpty ? name : '@$handle${name.isNotEmpty ? ' • $name' : ''}';

    final text = (post.text ?? '').trim();
    final preview = text.length <= 240 ? text : '${text.substring(0, 240)}…';

    return AuraCard(
      onTap: () => context.push('/posts/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AuraSurface.divider),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text(
                  byline.isEmpty ? 'Public entry' : byline,
                  style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AuraSurface.muted),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            preview.isEmpty ? '—' : preview,
            style: AuraText.body.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s10,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AuraSurface.muted),
            const SizedBox(width: AuraSpace.s8),
            Text(label, style: AuraText.small),
          ],
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}