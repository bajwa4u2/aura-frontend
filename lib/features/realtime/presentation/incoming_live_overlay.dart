import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../updates/notifications_repository.dart';
import '../application/realtime_providers.dart';

class AuraIncomingLiveLayer extends ConsumerStatefulWidget {
  const AuraIncomingLiveLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuraIncomingLiveLayer> createState() => _AuraIncomingLiveLayerState();
}

class _AuraIncomingLiveLayerState extends ConsumerState<AuraIncomingLiveLayer> {
  Timer? _timer;
  Map<String, dynamic>? _incoming;
  final Set<String> _dismissedIds = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCandidate(force: true));
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshCandidate());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCandidate({bool force = false}) async {
    if (!mounted || _busy) return;
    _busy = true;
    try {
      final repo = NotificationsRepository(ref.read(dioProvider));
      final items = await repo.list(limit: 30, forceRefresh: force);
      if (!mounted) return;
      final currentPath = GoRouterState.of(context).uri.path;
      final next = items.firstWhere(
        (item) => _isInterruptCandidate(item, currentPath),
        orElse: () => <String, dynamic>{},
      );
      setState(() {
        _incoming = next.isEmpty ? null : next;
      });
    } catch (_) {
      // Keep the shell stable even if notifications polling fails.
    } finally {
      _busy = false;
    }
  }

  bool _isInterruptCandidate(Map<String, dynamic> item, String currentPath) {
    final id = _stringOf(item['id']);
    if (id.isEmpty || _dismissedIds.contains(id)) return false;
    if (_stringOf(item['readAt']).isNotEmpty) return false;

    final data = _mapOf(item['data']);
    final attention = _stringOf(data['attention']).toUpperCase();
    if (attention != 'INTERRUPT') return false;

    final type = _stringOf(item['type']).toUpperCase();
    final communicationType = _stringOf(data['communicationType']).toUpperCase();
    final realtimeType = _stringOf(item['realtimeType']).toUpperCase();
    final isLive =
        type == 'LIVE' || communicationType == 'LIVE' || realtimeType.contains('LIVE');
    if (!isLive) return false;

    final deeplink = _resolveRoute(item);
    if (deeplink.isNotEmpty && _sameContext(currentPath, deeplink)) {
      return false;
    }

    return true;
  }

  bool _sameContext(String currentPath, String deeplink) {
    final current = currentPath.trim();
    final target = deeplink.trim();
    if (current.isEmpty || target.isEmpty) return false;
    if (current == target) return true;
    return current.startsWith(target) || target.startsWith(current);
  }

  String _resolveRoute(Map<String, dynamic> item) {
    final data = _mapOf(item['data']);
    final direct = _stringOf(item['deeplink']);
    if (direct.isNotEmpty) return direct;
    final nested = _stringOf(data['deeplink']);
    if (nested.isNotEmpty) return nested;
    final route = _stringOf(data['route']);
    if (route.isNotEmpty) return route;

    final threadId = _stringOf(item['threadId']).isNotEmpty
        ? _stringOf(item['threadId'])
        : _stringOf(data['threadId']);
    final spaceId = _stringOf(item['spaceId']).isNotEmpty
        ? _stringOf(item['spaceId'])
        : _stringOf(data['spaceId']);
    final sessionId = _stringOf(item['sessionId']).isNotEmpty
        ? _stringOf(item['sessionId'])
        : _stringOf(data['sessionId']);

    if (threadId.isNotEmpty && spaceId.isNotEmpty) {
      return '/me/correspondence/$spaceId/thread/$threadId';
    }
    if (spaceId.isNotEmpty) {
      return '/me/correspondence/$spaceId';
    }
    if (sessionId.isNotEmpty) {
      return '/realtime/$sessionId?action=join';
    }
    return '';
  }

  Future<void> _joinCurrent() async {
    final item = _incoming;
    if (item == null) return;
    final repo = NotificationsRepository(ref.read(dioProvider));
    final id = _stringOf(item['id']);
    final sessionId = _stringOf(item['sessionId']).isNotEmpty
        ? _stringOf(item['sessionId'])
        : _stringOf(_mapOf(item['data'])['sessionId']);
    final route = _resolveRoute(item);

    try {
      if (sessionId.isNotEmpty) {
        await ref.read(realtimeControllerProvider.notifier).join(sessionId);
      }
      if (id.isNotEmpty) {
        await repo.markRead(id);
      }
    } catch (_) {
      // Navigation should still happen even if join or markRead fails.
    }

    if (!mounted) return;
    setState(() {
      _incoming = null;
      if (id.isNotEmpty) {
        _dismissedIds.remove(id);
      }
    });

    if (route.isNotEmpty) {
      context.go(route);
    } else if (sessionId.isNotEmpty) {
      context.go('/realtime/$sessionId?action=join');
    }
  }

  void _dismissCurrent() {
    final item = _incoming;
    final id = _stringOf(item?['id']);
    if (id.isNotEmpty) {
      _dismissedIds.add(id);
    }
    setState(() {
      _incoming = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _incoming;
    if (item == null) {
      return widget.child;
    }

    final actor = _mapOf(item['actor']);
    final actorName = _firstNonEmpty([
      _stringOf(actor['displayName']),
      _stringOf(actor['handle']),
      _stringOf(item['actorName']),
      'Someone',
    ]);
    final title = _firstNonEmpty([
      _stringOf(item['title']),
      _stringOf(_mapOf(item['data'])['title']),
      'Live request',
    ]);
    final body = _firstNonEmpty([
      _stringOf(item['body']),
      _stringOf(_mapOf(item['data'])['body']),
      'Live is ready to join.',
    ]);
    final mode = _stringOf(_mapOf(item['data'])['mode']).toUpperCase();
    final modeLabel = mode == 'VIDEO'
        ? 'Video'
        : mode == 'SCREEN'
            ? 'Screen'
            : 'Audio';

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.55)),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: AuraCard(
                    padding: const EdgeInsets.all(AuraSpace.s20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$modeLabel live',
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        Text(
                          actorName,
                          style: AuraText.title,
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        Text(
                          title,
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        Text(body, style: AuraText.body),
                        const SizedBox(height: AuraSpace.s20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _dismissCurrent,
                                child: const Text('Dismiss'),
                              ),
                            ),
                            const SizedBox(width: AuraSpace.s12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _joinCurrent,
                                child: const Text('Join'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

String _stringOf(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
