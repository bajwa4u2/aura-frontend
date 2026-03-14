import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/profile_header.dart';

import '../../feed/presentation/widgets/post_card.dart';
import '../data/profile_repository.dart';

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
  late Future<ProfileBundle> _bundleFuture;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
  }

  Future<ProfileBundle> _load() async {
    final repo = ref.read(profileRepositoryProvider);

    final profile = await repo.fetchProfile(widget.handle);
    final posts = await repo.getUserPosts(widget.handle);
    final followDetail = await repo.getFollowStateDetail(widget.handle);

    return ProfileBundle(
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

  void _showMessage(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(profileRepositoryProvider);
    final isAuthed = ref.watch(isAuthedProvider);

    return AuraScaffold(
      title: 'Profile',
      body: FutureBuilder<ProfileBundle>(
        future: _bundleFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError || snap.data == null) {
            return AuraCard(
              child: Text(
                'Could not load profile.',
                style: AuraText.body,
              ),
            );
          }

          final bundle = snap.data!;
          final p = bundle.profile;
          final posts = bundle.posts;
          final followState = bundle.followState;

          final name =
              p.displayName.trim().isNotEmpty ? p.displayName : widget.handle;

          final bio = (p.bio ?? '').trim();
          final avatar = (p.avatarUrl ?? '').trim();

          final followers = p.followersCount;
          final following = p.followingCount;

          final label = switch (followState) {
            'following' => 'Following',
            'outgoing_pending' => 'Requested',
            _ => 'Follow',
          };

          final canTap =
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
                    value: '$followers',
                    onTap: () =>
                        context.push('/u/${widget.handle}/followers'),
                  ),
                  ProfileHeaderStat(
                    label: 'Following',
                    value: '$following',
                    onTap: () =>
                        context.push('/u/${widget.handle}/following'),
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
                      label: label,
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
                                _showMessage(
                                  'Could not update follow state',
                                );
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
                  child: Text('No work yet.', style: AuraText.body),
                )
              else
                Column(
                  children: posts
                      .map(
                        (p) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AuraSpace.s10),
                          child: PostCard(post: p),
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

class ProfileBundle {
  const ProfileBundle({
    required this.profile,
    required this.posts,
    required this.followState,
  });

  final Profile profile;
  final List<Post> posts;
  final String followState;
}
