import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

import '../../auth/auth_controller.dart';
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

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await AuthController(ref).logout(context);
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
      title: 'Aura',
      actions: [
        IconButton(
          tooltip: 'Compose',
          onPressed: () => _openCompose(context, ref),
          icon: const Icon(Icons.edit_outlined),
        ),
        if (isAuthed)
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (v) async {
              if (v == 'logout') {
                await _logout(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            icon: const Icon(Icons.more_horiz),
          ),
      ],
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
                crossAxisAlignment:
