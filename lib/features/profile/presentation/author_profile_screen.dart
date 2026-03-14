import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/profile_header.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider(handle));
    final controller = ref.read(profileControllerProvider(handle).notifier);
    final isAuthed = ref.watch(isAuthedProvider);

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
          if (profileState.loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (profileState.error != null)
            AuraCard(
              child: Text(
                'Could not load profile: ${profileState.error}',
                style: AuraText.body,
              ),
            )
          else if (profileState.profile == null)
            AuraCard(
              child: Text(
                'Profile not found.',
                style: AuraText.body,
              ),
            )
          else ...[
            Builder(
              builder: (context) {
                final p = profileState.profile!;
                final name = p.displayName.trim().isNotEmpty
                    ? p.displayName.trim()
                    : handle;
                final bio = p.bio?.trim() ?? '';
                final avatar = p.avatarUrl?.trim() ?? '';

                final actions = <ProfileHeaderAction>[
                  if (!isAuthed)
                    const ProfileHeaderAction(
                      label: 'Login to follow',
                      onTap: null,
                      primary: true,
                      icon: Icons.lock_outline,
                    )
                  else
                    ProfileHeaderAction(
                      label: p.isFollowing ? 'Following' : 'Follow',
                      primary: true,
                      icon: p.isFollowing
                          ? Icons.check
                          : Icons.person_add_alt_1,
                      onTap: () async {
                        try {
                          await controller.toggleFollow();
                          final updated =
                              ref.read(profileControllerProvider(handle)).profile;
                          if (updated == null) return;

                          _showMessage(
                            context,
                            updated.isFollowing
                                ? 'Followed'
                                : 'Unfollowed',
                          );
                        } catch (e) {
                          _showMessage(
                            context,
                            'Could not update follow state',
                          );
                        }
                      },
                    ),
                ];

                return ProfileHeader(
                  displayName: name,
                  handle: p.handle,
                  bio: bio,
                  avatarUrl: avatar,
                  stats: [
                    ProfileHeaderStat(
                      label: 'Followers',
                      value: '${p.followersCount}',
                      onTap: () => context.push('/u/$handle/followers'),
                    ),
                    ProfileHeaderStat(
                      label: 'Following',
                      value: '${p.followingCount}',
                      onTap: () => context.push('/u/$handle/following'),
                    ),
                  ],
                  actions: actions,
                );
              },
            ),
            const SizedBox(height: AuraSpace.s18),
            Text('Work', style: AuraText.title),
            const SizedBox(height: AuraSpace.s10),
            AuraCard(
              child: Text(
                'Profile header and follow state are now wired to the active profile controller. The work feed on this screen still needs to be reconnected to the current posts source.',
                style: AuraText.body,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
