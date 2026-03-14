import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';
import '../domain/profile.dart';

final followingProvider =
    FutureProvider.family<List<ProfileListItem>, String>((ref, handle) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getFollowing(handle);
});

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({
    super.key,
    required this.handle,
  });

  final String handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider(handle));

    return AuraScaffold(
      title: '@$handle following',
      child: followingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (_, __) => Center(
          child: Text(
            'Could not load following',
            style: AuraText.body,
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Not following anyone yet',
                style: AuraText.body,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s12),
            itemBuilder: (context, index) {
              final person = items[index];
              final displayName = (person.displayName ?? '').trim();
              final handleText = person.handle.trim();
              final avatarUrl = (person.avatarUrl ?? '').trim();

              return AuraCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s4,
                  ),
                  leading: CircleAvatar(
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  title: Text(
                    displayName.isNotEmpty ? displayName : '@$handleText',
                    style: AuraText.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: handleText.isNotEmpty
                      ? Text(
                          '@$handleText',
                          style: AuraText.small,
                        )
                      : null,
                  onTap: () {
                    if (handleText.isNotEmpty) {
                      context.push('/u/$handleText');
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}