import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/interactions/follows_repository.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

// C2 closeout — transport lives behind the canonical Follow repository;
// this screen renders the consent lifecycle and never owns HTTP.
final followRequestsProvider =
    FutureProvider<List<PersonFollowRequest>>((ref) {
  return ref.watch(followsRepositoryProvider).incomingFollowRequests();
});

class FollowRequestsScreen extends ConsumerStatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  ConsumerState<FollowRequestsScreen> createState() =>
      _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends ConsumerState<FollowRequestsScreen> {
  final Set<String> _busyIds = <String>{};

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _accept(PersonFollowRequest item) async {
    if (item.id.isEmpty || _busyIds.contains(item.id)) return;

    setState(() => _busyIds.add(item.id));
    try {
      await ref.read(followsRepositoryProvider).acceptFollowRequest(item.id);
      ref.invalidate(followRequestsProvider);
      _showMessage('Follow request accepted');
    } catch (_) {
      _showMessage('Could not accept follow request');
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(item.id));
      }
    }
  }

  Future<void> _decline(PersonFollowRequest item) async {
    if (item.id.isEmpty || _busyIds.contains(item.id)) return;

    setState(() => _busyIds.add(item.id));
    try {
      await ref.read(followsRepositoryProvider).declineFollowRequest(item.id);
      ref.invalidate(followRequestsProvider);
      _showMessage('Follow request declined');
    } catch (_) {
      _showMessage('Could not decline follow request');
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(item.id));
      }
    }
  }

  String _titleFor(PersonFollowRequest item) {
    final name = item.displayName.trim();
    final handle = item.handle.trim();
    if (name.isNotEmpty) return name;
    if (handle.isNotEmpty) return '@$handle';
    return 'Member';
    }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(followRequestsProvider);

    return AuraScaffold(
      title: 'Follow requests',
      body: requestsAsync.when(
        // C2 — canonical Follow surfaces speak through the C0 state authority.
        loading: () => const AuraProductState(
          state: ProductState.loading,
          headline: 'Loading requests…',
        ),
        error: (_, __) => AuraProductState(
          state: ProductState.retryableError,
          headline: 'Could not load follow requests',
          onRecover: () => ref.invalidate(followRequestsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const AuraProductState(
              state: ProductState.empty,
              subject: ProductNoun.person,
              headline: 'No follow requests',
              detail: 'New requests will appear here.',
              icon: Icons.person_add_alt_outlined,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AuraSpace.s10),
            itemBuilder: (context, index) {
              final item = items[index];
              final handle = item.handle.trim();
              final avatarUrl = item.avatarUrl.trim();
              final title = _titleFor(item);
              final isBusy = _busyIds.contains(item.id);

              return AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AuraAvatar(
                            name: title,
                            imageUrl: avatarUrl,
                            size: 40,
                          ),
                          const SizedBox(width: AuraSpace.s12),
                          Expanded(
                            child: GestureDetector(
                              onTap: handle.isNotEmpty
                                  ? () => context.push('/u/$handle')
                                  : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AuraText.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (handle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '@$handle',
                                      style: AuraText.small.copyWith(
                                        color: AuraSurface.muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      Row(
                        children: [
                          Expanded(
                            child: AuraPrimaryButton(
                              label: isBusy ? 'Working…' : 'Accept',
                              onPressed: isBusy ? null : () => _accept(item),
                              icon: Icons.check_rounded,
                            ),
                          ),
                          const SizedBox(width: AuraSpace.s10),
                          Expanded(
                            child: AuraSecondaryButton(
                              label: 'Deny',
                              onPressed: isBusy ? null : () => _decline(item),
                              icon: Icons.close_rounded,
                            ),
                          ),
                        ],
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
