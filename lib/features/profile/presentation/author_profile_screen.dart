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
import '../../feed/domain/post.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import '../providers.dart';

class AuthorProfileScreen extends ConsumerStatefulWidget {
  const AuthorProfileScreen({
    super.key,
    required this.handle,
  });

  final String handle;

  @override
  ConsumerState<AuthorProfileScreen> createState() =>
      _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends ConsumerState<AuthorProfileScreen> {
  late Future<_ProfileBundle> _bundleFuture;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
  }

  Future<_ProfileBundle> _load() async {
    final repo = ref.read(profileRepositoryProvider);

    final profile = await repo.fetchProfile(widget.handle);
    final posts = await repo.getUserPosts(widget.handle);
    final followDetail = await repo.getFollowStateDetail(widget.handle);

    return _ProfileBundle(
      profile: profile,
      posts: posts,
      followState: followDetail.state,
    );
  }

  void _reload() {
    setState(() {
      _bundleFuture = _load();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(profileRepositoryProvider);
    final isAuthed = ref.watch(isAuthedProvider);

    return AuraScaffold(
      title: 'Profile',
      body: FutureBuilder<_ProfileBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s12,
                AuraSpace.s16,
                AuraSpace.s24,
              ),
              children: [
                AuraCard(
                  child: Text(
                    'Could not load profile.',
                    style: AuraText.body,
                  ),
                ),
              ],
            );
          }

          final bundle = snapshot.data!;
          final Profile profile = bundle.profile;
          final List<Post> posts = bundle.posts;
          final String followState = bundle.followState;

          final String name = profile.displayName.trim().isNotEmpty
              ? profile.displayName.trim()
              : widget.handle;
          final String bio = (profile.bio ?? '').trim();
          final String avatar = (profile.avatarUrl ?? '').trim();

          final String followLabel = switch (followState) {
            'following' => 'Following',
            'outgoing_pending' => 'Requested',
            _ => 'Follow',
          };

          final bool canTap =
              followState == 'none' || followState == 'outgoing_pending';

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s12,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: [
              ProfileHeader(
                displayName: name,
                handle: widget.handle,
                bio: bio,
                avatarUrl: avatar,
                stats: [
                  ProfileHeaderStat(
                    label: 'Followers',
                    value: '${profile.followersCount}',
                    onTap: () => context.push('/u/${widget.handle}/followers'),
                  ),
                  ProfileHeaderStat(
                    label: 'Following',
                    value: '${profile.followingCount}',
                    onTap: () => context.push('/u/${widget.handle}/following'),
                  ),
                ],
                actions: [
                  if (!isAuthed)
                    const ProfileHeaderAction(
                      label: 'Login to follow',
                      primary: true,
                      onTap: null,
                      icon: Icons.lock_outline,
                    )
                  else
                    ProfileHeaderAction(
                      label: followLabel,
                      primary: true,
                      icon: followState == 'following'
                          ? Icons.check
                          : followState == 'outgoing_pending'
                              ? Icons.schedule
                              : Icons.person_add_alt_1,
                      onTap: !canTap
                          ? null
                          : () async {
                              try {
                                if (followState == 'outgoing_pending') {
                                  await repo.unfollow(widget.handle);
                                  _showMessage('Request canceled');
                                } else {
                                  await repo.follow(widget.handle);
                                  _showMessage('Follow request sent');
                                }
                                _reload();
                              } catch (_) {
                                _showMessage('Could not update follow state');
                              }
                            },
                    ),
                ],
              ),
              const SizedBox(height: AuraSpace.s18),
              Text('Work', style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              if (posts.isEmpty)
                AuraCard(
                  child: Text(
                    'No work yet.',
                    style: AuraText.body,
                  ),
                )
              else
                Column(
                  children: posts
                      .map(
                        (post) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AuraSpace.s10,
                          ),
                          child: PostCard(post: post),
                        ),
                      )
                      .toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileBundle {
  const _ProfileBundle({
    required this.profile,
    required this.posts,
    required this.followState,
  });

  final Profile profile;
  final List<Post> posts;
  final String followState;
}
