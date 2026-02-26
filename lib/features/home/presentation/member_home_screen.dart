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

final draftProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final dio = ref.watch(dioProvider);

  final res = await dio.get('/posts/draft');
  final data = res.data;

  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final draft = map['draft'];
    if (draft == null) return null;
    if (draft is Map) return Map<String, dynamic>.from(draft);
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
        padding: EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          const _HeroCard(),

          SizedBox(height: AuraSpace.s18),

          draftAsync.when(
            data: (draft) {
              if (!isAuthed) return const SizedBox.shrink();
              if (draft == null) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle(title: 'Draft'),
                  SizedBox(height: AuraSpace.s10),
                  AuraCard(
                    onTap: () => context.push('/compose'),
                    child: Text(
                      'Continue your draft.',
                      style: AuraText.body,
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          SizedBox(height: AuraSpace.s18),

          _SectionTitle(title: 'Saved'),
          SizedBox(height: AuraSpace.s10),

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
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
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
                    header,
                    SizedBox(height: AuraSpace.s10),
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
                  header,
                  SizedBox(height: AuraSpace.s10),
                  ...posts.take(2).map(
                        (p) => Padding(
                          padding: EdgeInsets.only(bottom: AuraSpace.s10),
                          child: PostCard(post: p, compact: true),
                        ),
                      ),
                ],
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) =>
                AuraCard(child: Text('Could not load saved: $e', style: AuraText.body)),
          ),

          SizedBox(height: AuraSpace.s18),

          _SectionTitle(title: 'Latest'),
          SizedBox(height: AuraSpace.s10),

          feedAsync.when(
            data: (posts) {
              final top = posts.take(6).toList();
              if (top.isEmpty) {
                return AuraCard(child: Text('No posts yet.', style: AuraText.body));
              }
              return Column(
                children: top
                    .map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: AuraSpace.s18),
                        child: PostCard(post: p),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) =>
                AuraCard(child: Text('Could not load feed: $e', style: AuraText.body)),
          ),

          SizedBox(height: AuraSpace.s18),
          _SectionTitle(title: 'Quiet tools'),
          SizedBox(height: AuraSpace.s10),
          const _ToolsRow(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settle. Read. Write with care.', style: AuraText.title),
          SizedBox(height: AuraSpace.s8),
          Text(
            'A quiet space for correspondence and durable thought.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w800));
  }
}

class _ToolsRow extends StatelessWidget {
  const _ToolsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AuraCard(
            onTap: () => context.push('/updates'),
            child: Text('Updates', style: AuraText.body),
          ),
        ),
        SizedBox(width: AuraSpace.s10),
        Expanded(
          child: AuraCard(
            onTap: () => context.push('/search'),
            child: Text('Search', style: AuraText.body),
          ),
        ),
        SizedBox(width: AuraSpace.s10),
        Expanded(
          child: AuraCard(
            onTap: () => context.push('/me'),
            child: Text('Me', style: AuraText.body),
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Padding(
        padding: EdgeInsets.all(AuraSpace.s16),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}