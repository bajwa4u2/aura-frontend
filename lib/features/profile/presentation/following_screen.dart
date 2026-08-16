import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/profile.dart';
import '../providers.dart';

final followingProvider = FutureProvider.family<List<ProfileListItem>, String>((
  ref,
  handle,
) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getFollowing(handle);
});

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key, required this.handle});

  final String handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider(handle));

    return AuraScaffold(
      title: '@$handle following',
      child: followingAsync.when(
        // C2 — canonical Follow surfaces speak through the C0 state authority.
        loading: () => const AuraProductState(
          state: ProductState.loading,
          headline: 'Loading following…',
        ),
        error: (_, __) => AuraProductState(
          state: ProductState.retryableError,
          headline: 'Could not load following',
          onRecover: () => ref.invalidate(followingProvider(handle)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const AuraProductState(
              state: ProductState.empty,
              subject: ProductNoun.person,
              headline: 'Not following anyone yet',
              detail: 'Accounts followed will appear here.',
              icon: Icons.person_add_alt_1_outlined,
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
