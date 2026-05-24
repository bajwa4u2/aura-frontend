import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class FollowRequestItem {
  const FollowRequestItem({
    required this.id,
    required this.createdAt,
    required this.requesterId,
    required this.handle,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final DateTime? createdAt;
  final String requesterId;
  final String handle;
  final String displayName;
  final String avatarUrl;

  factory FollowRequestItem.fromJson(Map<String, dynamic> json) {
    final requesterRaw = json['requester'];
    final requester = requesterRaw is Map<String, dynamic>
        ? requesterRaw
        : requesterRaw is Map
            ? Map<String, dynamic>.from(requesterRaw)
            : <String, dynamic>{};

    DateTime? parsedCreatedAt;
    final createdAtRaw = (json['createdAt'] ?? '').toString().trim();
    if (createdAtRaw.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw);
    }

    return FollowRequestItem(
      id: (json['id'] ?? '').toString().trim(),
      createdAt: parsedCreatedAt,
      requesterId: (requester['id'] ?? '').toString().trim(),
      handle: (requester['handle'] ?? '').toString().trim(),
      displayName: (requester['displayName'] ?? '').toString().trim(),
      avatarUrl: (requester['avatarUrl'] ?? '').toString().trim(),
    );
  }
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

final followRequestsProvider =
    FutureProvider<List<FollowRequestItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me/follow/requests/inbox');

  final raw = res.data;
  final root = _asMap(raw);

  dynamic itemsRaw = root['items'];
  if (itemsRaw == null && root['data'] is Map) {
    final inner = Map<String, dynamic>.from(root['data'] as Map);
    itemsRaw = inner['items'];
  }

  if (itemsRaw is! List) return const [];

  return itemsRaw
      .whereType<Map>()
      .map((e) => FollowRequestItem.fromJson(Map<String, dynamic>.from(e)))
      .where((e) => e.id.isNotEmpty)
      .toList();
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

  Future<void> _accept(FollowRequestItem item) async {
    if (item.id.isEmpty || _busyIds.contains(item.id)) return;

    setState(() => _busyIds.add(item.id));
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/users/me/follow/requests/${item.id}/accept');
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

  Future<void> _decline(FollowRequestItem item) async {
    if (item.id.isEmpty || _busyIds.contains(item.id)) return;

    setState(() => _busyIds.add(item.id));
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/users/me/follow/requests/${item.id}/decline');
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

  String _titleFor(FollowRequestItem item) {
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
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading requests…'),
        ),
        error: (_, __) => const Center(
          child: AuraErrorState(
            title: 'Could not load follow requests',
            body: 'Check your connection and try again.',
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: AuraEmptyState(
                icon: Icons.person_add_alt_outlined,
                title: 'No follow requests',
                body: 'New requests will appear here.',
              ),
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
