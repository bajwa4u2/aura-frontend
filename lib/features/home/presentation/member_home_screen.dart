import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

import '../../feed/domain/post.dart';
import '../../feed/providers.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../saves/providers.dart';

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

/// Unwrap common envelopes:
/// - { ok:true, data:{...} }
/// - { ok:true, data:{ data:{...} } }
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
  final fallback = _PinnedAnnouncement.tryFrom(m);
  return fallback;
}

final pinnedAnnouncementProvider =
    FutureProvider.autoDispose<_PinnedAnnouncement?>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/announcements/pinned');
  return _unwrapPinned(res.data);
});

final draftProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/draft');
  final raw = res.data;

  final root = _asMap(raw);
  final topDraft = root['draft'];
  if (topDraft is Map) return Map<String, dynamic>.from(topDraft);

  final m = _unwrapMap(raw);

  final innerDraft = m['draft'];
  if (innerDraft is Map) return Map<String, dynamic>.from(innerDraft);

  if (m.isNotEmpty &&
      (m['id'] != null || m['title'] != null || m['body'] != null)) {
    return m;
  }

  return null;
});

List<Post> _coercePosts(dynamic raw) {
  if (raw is List<Post>) return raw;

  if (raw is List) {
    final out = <Post>[];
    for (final item in raw) {
      if (item is Post) {
        out.add(item);
        continue;
      }
      if (item is Map) {
        out.add(Post.fromJson((item as Map).cast<String, dynamic>()));
        continue;
      }
    }
    return out;
  }

  return const <Post>[];
}

class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  Future<void> _openCompose(BuildContext context, WidgetRef ref) async {
    await context.push('/compose');
    ref.invalidate(draftProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthedProvider);
    final feedAsync = ref.watch(feedProvider);
    final savedAsync = ref.watch(savedPostsProvider);

    final draftAsync = isAuthed
        ? ref.watch(draftProvider)
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          draftAsync.when(
            data: (draft) {
              final hasDraft = draft != null;
              return _ComposerEntryCard(
                hasDraft: hasDraft,
                onTap: () => _openCompose(context, ref),
              );
            },
            loading: () => _ComposerEntryCard(
              hasDraft: false,
              onTap: () => _openCompose(context, ref),
            ),
            error: (_, __) => _ComposerEntryCard(
              hasDraft: false,
              onTap: () => _openCompose(context, ref),
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          feedAsync.when(
            data: (posts) {
              final top = posts.take(6).toList();

              if (top.isEmpty) {
                return AuraCard(
                  child: Text('No posts yet.', style: AuraText.body),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(title: 'Latest'),
                  const SizedBox(height: AuraSpace.s12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: top.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AuraSpace.s16),
                    itemBuilder: (context, i) {
                      return PostCard(post: top[i]);
                    },
                  ),
                ],
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => AuraCard(
              child: Text('Could not load feed: $e', style: AuraText.body),
            ),
          ),
          const SizedBox(height: AuraSpace.s18),
          const _PinnedAnnouncementBanner(),
          const SizedBox(height: AuraSpace.s18),
          savedAsync.when(
            data: (raw) {
              final posts = _coercePosts(raw);

              final header = AuraCard(
                onTap: () => context.push('/saved'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Saved posts',
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              );

              if (posts.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle(title: 'Saved'),
                    const SizedBox(height: AuraSpace.s10),
                    header,
                    const SizedBox(height: AuraSpace.s10),
                    AuraCard(
                      onTap: () => context.push('/saved'),
                      child: Text(
                        'Save something you want to return to. It will live here.',
                        style: AuraText.body,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle(title: 'Saved'),
                  const SizedBox(height: AuraSpace.s10),
                  header,
                  const SizedBox(height: AuraSpace.s10),
                  ...posts.take(2).map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                          child: PostCard(post: p, compact: true),
                        ),
                      ),
                ],
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => AuraCard(
              child: Text('Could not load saved: $e', style: AuraText.body),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerEntryCard extends StatelessWidget {
  const _ComposerEntryCard({
    required this.hasDraft,
    required this.onTap,
  });

  final bool hasDraft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasDraft ? 'Continue writing' : 'Write something',
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            hasDraft
                ? 'Your draft is waiting. Return to it with care.'
                : 'Begin a post, a reflection, or a piece of correspondence.',
            style: AuraText.body,
          ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
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
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}