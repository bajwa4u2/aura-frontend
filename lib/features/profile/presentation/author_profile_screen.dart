import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
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

final isFollowingProvider = FutureProvider.family<bool, String>((ref, handle) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.isFollowing(handle);
});

/// Used to detect when viewing your own public profile
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
    final isAuthed = ref.watch(isAuthedProvider);
    final myHandleAsync = isAuthed ? ref.watch(myHandleProvider) : null;

    return AuraScaffold(
      title: 'Author',
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
        padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          userAsync.when(
            data: (u) {
              final name = u.displayName.isNotEmpty ? u.displayName : handle;
              final bio = u.bio;
              final avatar = (u.avatarUrl ?? '').trim();

              final isSelf = isAuthed
                  ? (myHandleAsync?.maybeWhen(data: (h) => h == handle, orElse: () => false) ?? false)
                  : false;

              return AuraCard(
                padding: EdgeInsets.all(AuraSpace.s18),
                child: SizedBox(
                  height: 230,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0x332E2A26),
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'A') : null,
                          ),
                          SizedBox(width: AuraSpace.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: AuraText.title),
                                SizedBox(height: AuraSpace.s4),
                                Text('@$handle', style: AuraText.muted),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AuraSpace.s12),
                      Text(
                        bio.isNotEmpty ? bio : 'Curated work. Responsible conversation.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.body.copyWith(height: 1.35),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: (!isAuthed || isSelf)
                                ? null
                                : () async {
                                    final repo = ref.read(profileRepositoryProvider);
                                    final following =
                                        await ref.read(isFollowingProvider(handle).future).catchError((_) => false);

                                    if (following) {
                                      await repo.unfollow(handle);
                                    } else {
                                      await repo.follow(handle);
                                    }

                                    ref.invalidate(isFollowingProvider(handle));
                                  },
                            child: Consumer(
                              builder: (context, ref, _) {
                                if (!isAuthed) return const Text('Login to follow');
                                if (isSelf) return const Text('This is you');

                                final following = ref.watch(isFollowingProvider(handle));
                                return following.when(
                                  data: (v) => Text(v ? 'Following' : 'Follow'),
                                  loading: () => const Text('…'),
                                  error: (_, __) => const Text('Follow'),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.all(AuraSpace.s12),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AuraCard(child: Text('Could not load author: $e', style: AuraText.body)),
          ),
          SizedBox(height: AuraSpace.s16),
          Text('Selected work', style: AuraText.title),
          SizedBox(height: AuraSpace.s10),
          postsAsync.when(
            data: (items) {
              if (items.isEmpty) return AuraCard(child: Text('No work yet.', style: AuraText.body));
              return Column(
                children: items
                    .map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: AuraSpace.s10),
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
            error: (e, _) => AuraCard(child: Text('Could not load posts: $e', style: AuraText.body)),
          ),
        ],
      ),
    );
  }
}
