import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/net/dio_provider.dart';
import '../providers.dart';
import '../domain/profile.dart';

final followRequestsProvider =
    FutureProvider<List<ProfileListItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me/follow-requests');

  final raw = res.data;
  if (raw is Map && raw['data'] is List) {
    return (raw['data'] as List)
        .whereType<Map>()
        .map((e) => ProfileListItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  return [];
});

class FollowRequestsScreen extends ConsumerWidget {
  const FollowRequestsScreen({super.key});

  Future<void> _accept(
      WidgetRef ref, String handle, BuildContext context) async {
    final dio = ref.read(dioProvider);

    await dio.post('/users/$handle/follow/accept');

    ref.invalidate(followRequestsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Follow request accepted')),
    );
  }

  Future<void> _deny(
      WidgetRef ref, String handle, BuildContext context) async {
    final dio = ref.read(dioProvider);

    await dio.post('/users/$handle/follow/deny');

    ref.invalidate(followRequestsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Follow request denied')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(followRequestsProvider);

    return AuraScaffold(
      title: 'Follow requests',
      body: requestsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (_, __) => Center(
          child: Text(
            'Could not load follow requests',
            style: AuraText.body,
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No follow requests',
                style: AuraText.body,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AuraSpace.s12),
            itemBuilder: (context, index) {
              final person = items[index];

              final displayName = (person.displayName ?? '').trim();
              final handle = person.handle.trim();
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
                    displayName.isNotEmpty
                        ? displayName
                        : '@$handle',
                    style: AuraText.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '@$handle',
                    style: AuraText.small,
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () =>
                            _accept(ref, handle, context),
                        child: const Text('Accept'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            _deny(ref, handle, context),
                        child: const Text('Deny'),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (handle.isNotEmpty) {
                      context.push('/u/$handle');
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