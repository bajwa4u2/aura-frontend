import 'package:dio/dio.dart';
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
import '../../posts/presentation/widgets/post_card.dart';
import '../domain/profile.dart';
import '../providers.dart';

final authorProvider = FutureProvider.family<Profile, String>((ref, handle) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getUser(handle);
});

final authorPostsProvider = FutureProvider.family<List<Post>, String>((ref, handle) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getUserPosts(handle, limit: 20);
});

final followStateProvider = FutureProvider.family<String, String>((ref, handle) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getFollowState(handle);
});

final followersProvider =
    FutureProvider.family<List<ProfileListItem>, String>((ref, handle) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getFollowers(handle);
});

final followingProvider =
    FutureProvider.family<List<ProfileListItem>, String>((ref, handle) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getFollowing(handle);
});

final myHandleProvider = FutureProvider<String>((ref) async {
  final dio = ref.read(dioProvider);

  Response res;
  try {
    res = await dio.get('/users/me');
  } catch (_) {
    res = await dio.get('/auth/me');
  }

  final data = res.data;
  if (data is Map) {
    final outer = data['data'];
    if (outer is Map) {
      return (outer['handle'] ?? '').toString().trim();
    }
    return (data['handle'] ?? '').toString().trim();
  }
  return '';
});

class AuthorProfileScreen extends ConsumerWidget {
  const AuthorProfileScreen({super.key, required this.handle});
  final String handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authorProvider(handle));
    final postsAsync = ref.watch(authorPostsProvider(handle));
    final followersAsync = ref.watch(followersProvider(handle));
    final followingAsync = ref.watch(followingProvider(handle));
    final isAuthed = ref.watch(isAuthedProvider);
    final myHandleAsync = isAuthed ? ref.watch(myHandleProvider) : null;

    return AuraScaffold(
      
      actions: [
        if (isAuthed)
          myHandleAsync?.maybeWhen(
                data: (me) => me != handle
                    ? IconButton(
                        tooltip: 'Support',
                        onPressed: () => context.push('/support/$handle'),
                        icon: const Icon(Icons.volunteer_activism_outlined),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ) ??
              const SizedBox.shrink(),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          userAsync.when(
            data: (u) {
              final name = u.displayName.isNotEmpty ? u.displayName : handle;
              final bio = u.bio ?? '';
              final avatar = (u.avatarUrl ?? '').trim();

              final isSelf = isAuthed
                  ? (myHandleAsync?.maybeWhen(
                        data: (h) => h == handle,
                        orElse: () => false,
                      ) ??
                      false)
                  : false;

              final followersCount = followersAsync.maybeWhen(
                data: (items) => items.length,
                orElse: () => u.followersCount,
              );
              final followingCount = followingAsync.maybeWhen(
                data: (items) => items.length,
                orElse: () => u.followingCount,
              );

              return AuraCard(
                padding: const EdgeInsets.all(AuraSpace.s18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0x332E2A26),
                          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar.isEmpty
                              ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'A')
                              : null,
                        ),
                        const SizedBox(width: AuraSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: AuraText.title),
                              const SizedBox(height: AuraSpace.s4),
                              Text('@$handle', style: AuraText.muted),
                              const SizedBox(height: AuraSpace.s10),
                              Wrap(
                                spacing: AuraSpace.s14,
                                runSpacing: AuraSpace.s8,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => _ProfileConnectionsScreen(
                                            
                                            handle: handle,
                                            kind: _ConnectionsKind.followers,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      '$followersCount followers',
                                      style: AuraText.small.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => _ProfileConnectionsScreen(
                                            
                                            handle: handle,
                                            kind: _ConnectionsKind.following,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      '$followingCount following',
                                      style: AuraText.small.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    Text(
                      bio.isNotEmpty ? bio : 'Curated work. Responsible conversation.',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.body.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    Row(
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            if (!isAuthed) {
                              return const FilledButton(
                                onPressed: null,
                                child: Text('Login to follow'),
                              );
                            }

                            if (isSelf) {
                              return const FilledButton(
                                onPressed: null,
                                child: Text('This is you'),
                              );
                            }

                            final stateAsync = ref.watch(followStateProvider(handle));

                            return stateAsync.when(
                              data: (state) {
                                final trimmed = state.trim();

                                final label = switch (trimmed) {
                                  'following' => 'Following',
                                  'outgoing_pending' => 'Requested',
                                  'incoming_pending' => 'Pending',
                                  _ => 'Follow',
                                };

                                final canTap =
                                    trimmed == 'none' || trimmed == 'outgoing_pending';

                                return FilledButton(
                                  onPressed: !canTap
                                      ? null
                                      : () async {
                                          final repo = ref.read(profileRepositoryProvider);

                                          if (trimmed == 'outgoing_pending') {
                                            await repo.unfollow(handle);
                                          } else {
                                            await repo.follow(handle);
                                          }

                                          ref.invalidate(followStateProvider(handle));
                                        },
                                  child: Text(label),
                                );
                              },
                              loading: () => const FilledButton(
                                onPressed: null,
                                child: Text('…'),
                              ),
                              error: (_, __) => FilledButton(
                                onPressed: () => ref.invalidate(followStateProvider(handle)),
                                child: const Text('Follow'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(AuraSpace.s12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AuraCard(
              child: Text('Could not load author: $e', style: AuraText.body),
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          Text('Selected work', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          postsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return AuraCard(
                  child: Text('No work yet.', style: AuraText.body),
                );
              }

              return Column(
                children: items
                    .map<Widget>(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                        child: PostCard(post: p, compact: false),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => AuraCard(
              child: Text('Could not load posts: $e', style: AuraText.body),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ConnectionsKind { followers, following }

class _ProfileConnectionsScreen extends ConsumerWidget {
  const _ProfileConnectionsScreen({
    required this.title,
    required this.handle,
    required this.kind,
  });

  final String title;
  final String handle;
  final _ConnectionsKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = kind == _ConnectionsKind.followers
        ? ref.watch(followersProvider(handle))
        : ref.watch(followingProvider(handle));

    return AuraScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return AuraCard(
                  child: Text('No entries yet.', style: AuraText.body),
                );
              }

              return Column(
                children: items
                    .map<Widget>((item) {
                      final name = item.displayName.isNotEmpty
                          ? item.displayName
                          : (item.handle.isNotEmpty ? item.handle : 'Author');
                      final avatar = (item.avatarUrl ?? '').trim();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                        child: AuraCard(
                          onTap: item.handle.isEmpty
                              ? null
                              : () => context.push('/u/${item.handle}'),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0x332E2A26),
                                backgroundImage:
                                    avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar.isEmpty
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                      )
                                    : null,
                              ),
                              const SizedBox(width: AuraSpace.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: AuraText.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (item.handle.isNotEmpty)
                                      Text('@${item.handle}', style: AuraText.muted),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => AuraCard(
              child: Text('Could not load $title: $e', style: AuraText.body),
            ),
          ),
        ],
      ),
    );
  }
}