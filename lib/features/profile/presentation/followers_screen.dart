import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/auth/session_providers.dart';
import '../../updates/providers.dart';
import '../providers.dart';
import '../domain/profile.dart';

final followersProvider = FutureProvider.family<List<ProfileListItem>, String>((
  ref,
  handle,
) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getFollowers(handle);
});

class FollowersScreen extends ConsumerStatefulWidget {
  const FollowersScreen({super.key, required this.handle});

  final String handle;

  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen> {
  bool _attentionMarked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_attentionMarked) return;
    _attentionMarked = true;
    Future.microtask(() async {
      final me = await ref.read(authMeDataProvider.future);
      final user = me['user'];
      final myHandle = (user is Map ? user['handle'] : me['handle'])
          ?.toString()
          .trim()
          .toLowerCase();
      if (myHandle == null || myHandle != widget.handle.trim().toLowerCase()) {
        return;
      }
      await ref.read(notificationsControllerProvider.notifier).markReadForTarget(
        types: const ['FOLLOW'],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.handle;
    final followersAsync = ref.watch(followersProvider(handle));

    return AuraScaffold(
      title: '@$handle followers',
      child: followersAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading followers…'),
        ),
        error: (_, __) => const Center(
          child: AuraErrorState(
            title: 'Could not load followers',
            body: 'Check your connection and try again.',
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: AuraEmptyState(
                icon: Icons.people_outline,
                title: 'No followers yet',
                body: 'When people follow this account, they will appear here.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
            itemBuilder: (context, index) {
              final person = items[index];
              final displayName = person.displayName.trim();
              final handleText = person.handle.trim();
              final avatarUrl = (person.avatarUrl ?? '').trim();
              final label = displayName.isNotEmpty
                  ? displayName
                  : '@$handleText';

              return AuraCard(
                onTap: handleText.isNotEmpty
                    ? () => context.push('/u/$handleText')
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s14,
                    vertical: AuraSpace.s12,
                  ),
                  child: Row(
                    children: [
                      AuraAvatar(name: label, imageUrl: avatarUrl, size: 40),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: AuraText.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (handleText.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '@$handleText',
                                style: AuraText.small.copyWith(
                                  color: AuraSurface.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AuraSurface.faint,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
