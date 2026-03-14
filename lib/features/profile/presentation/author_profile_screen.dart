import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/profile_header.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../data/profile_repository.dart';
import '../providers.dart';

class AuthorProfileScreen extends ConsumerWidget {
  const AuthorProfileScreen({
    super.key,
    required this.handle,
  });

  final String handle;

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _invalidateProfileState(WidgetRef ref) {
    ref.invalidate(authorProvider(handle));
    ref.invalidate(authorPostsProvider(handle));
    ref.invalidate(followStateProvider(handle));
    ref.invalidate(followersProvider(handle));
    ref.invalidate(followingProvider(handle));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authorProvider(handle));
    final postsAsync = ref.watch(authorPostsProvider(handle));
    final followersAsync = ref.watch(followersProvider(handle));
    final followingAsync = ref.watch(followingProvider(handle));

    final isAuthed = ref.watch(isAuthedProvider);
    final myHandleAsync = isAuthed ? ref.watch(myHandleProvider) : null;

    return AuraScaffold(
      title: 'Profile',
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
              final bio = (u.bio ?? '').trim();
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

              return Consumer(
                builder: (context, ref, _) {
                  if (!isAuthed) {
                    return ProfileHeader(
                      displayName: name,
                      handle: handle,
                      bio: bio,
                      avatarUrl: avatar,
                      stats: [
                        ProfileHeaderStat(
                          label: 'Followers',
                          value: '$followersCount',
                          onTap: () => context.push('/u/$handle/followers'),
                        ),
                        ProfileHeaderStat(
                          label: 'Following',
                          value: '$followingCount',
                          onTap: () => context.push('/u/$handle/following'),
                        ),
                      ],
                      actions: const [
                        ProfileHeaderAction(
                          label: 'Login to follow',
                          onTap: null,
                          primary: true,
                          icon: Icons.lock_outline,
                        ),
                      ],
                    );
                  }

                  if (isSelf) {
                    return ProfileHeader(
                      displayName: name,
                      handle: handle,
                      bio: bio,
                      avatarUrl: avatar,
                      stats: [
                        ProfileHeaderStat(
                          label: 'Followers',
                          value: '$followersCount',
                          onTap: () => context.push('/u/$handle/followers'),
                        ),
                        ProfileHeaderStat(
                          label: 'Following',
                          value: '$followingCount',
                          onTap: () => context.push('/u/$handle/following'),
                        ),
                      ],
                    );
                  }

                  final stateAsync = ref.watch(followStateProvider(handle));

                  return stateAsync.when(
                    data: (detail) {
                      final repo = ref.read(profileRepositoryProvider);
                      final trimmed = detail.state.trim();

                      final label = switch (trimmed) {
                        'following' => 'Following',
                        'outgoing_pending' => 'Requested',
                        _ => 'Follow',
                      };

                      final canTap =
                          trimmed == 'none' || trimmed == 'outgoing_pending';

                      return ProfileHeader(
                        displayName: name,
                        handle: handle,
                        bio: bio,
                        avatarUrl: avatar,
                        stats: [
                          ProfileHeaderStat(
                            label: 'Followers',
                            value: '$followersCount',
                            onTap: () => context.push('/u/$handle/followers'),
                          ),
                          ProfileHeaderStat(
                            label: 'Following',
                            value: '$followingCount',
                            onTap: () => context.push('/u/$handle/following'),
                          ),
                        ],
                        actions: [
                          ProfileHeaderAction(
                            label: label,
                            primary: true,
                            icon: trimmed == 'following'
                                ? Icons.check
                                : trimmed == 'outgoing_pending'
                                    ? Icons.schedule
                                    : Icons.person_add_alt_1,
                            onTap: !canTap
                                ? null
                                : () async {
                                    try {
                                      if (trimmed == 'outgoing_pending') {
                                        await repo.unfollow(handle);
                                        _showMessage(
                                          context,
                                          'Request canceled',
                                        );
                                      } else {
                                        await repo.follow(handle);
                                        _showMessage(
                                          context,
                                          'Follow request sent',
                                        );
                                      }

                                      _invalidateProfileState(ref);
                                    } catch (_) {
                                      _showMessage(
                                        context,
                                        'Could not update follow state',
                                      );
                                    }
                                  },
                          ),
                        ],
                      );
                    },
                    loading: () => ProfileHeader(
                      displayName: name,
                      handle: handle,
                      bio: bio,
                      avatarUrl: avatar,
                      stats: [
                        ProfileHeaderStat(
                          label: 'Followers',
                          value: '$followersCount',
                          onTap: () => context.push('/u/$handle/followers'),
                        ),
                        ProfileHeaderStat(
                          label: 'Following',
                          value: '$followingCount',
                          onTap: () => context.push('/u/$handle/following'),
                        ),
                      ],
                      actions: const [
                        ProfileHeaderAction(
                          label: '…',
                          onTap: null,
                          primary: true,
                        ),
                      ],
                    ),
                    error: (_, __) => ProfileHeader(
                      displayName: name,
                      handle: handle,
                      bio: bio,
                      avatarUrl: avatar,
                      stats: [
                        ProfileHeaderStat(
                          label: 'Followers',
                          value: '$followersCount',
                          onTap: () => context.push('/u/$handle/followers'),
                        ),
                        ProfileHeaderStat(
                          label: 'Following',
                          value: '$followingCount',
                          onTap: () => context.push('/u/$handle/following'),
                        ),
                      ],
                      actions: [
                        ProfileHeaderAction(
                          label: 'Follow',
                          primary: true,
                          icon: Icons.person_add_alt_1,
                          onTap: () => ref.invalidate(followStateProvider(handle)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AuraCard(
              child: Text('Could not load profile: $e'),
            ),
          ),
          const SizedBox(height: AuraSpace.s18),
          Text('Work', style: AuraText.title),
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
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                        child: PostCard(post: p),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AuraCard(
              child: Text('Could not load posts: $e'),
            ),
          ),
        ],
      ),
    );
  }
}
