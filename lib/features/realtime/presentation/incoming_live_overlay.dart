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
  ConsumerState<AuraIncomingLiveLayer> createState() =>
      _AuraIncomingLiveLayerState();
}

class _AuraIncomingLiveLayerState
    extends ConsumerState<AuraIncomingLiveLayer> {
  Timer? _timer;
  Map<String, dynamic>? _incoming;
  final Set<String> _dismissedIds = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _refreshCandidate(force: true));
    _timer =
        Timer.periodic(const Duration(seconds: 4), (_) => _refreshCandidate());
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
    } catch (_) {} finally {
      _busy = false;
    }
  }

  bool _isInterruptCandidate(Map<String, dynamic> item, String currentPath) {
    final id = _stringOf(item['id']);
    if (id.isEmpty || _dismissedIds.contains(id)) return false;
    if (_stringOf(item['readAt']).isNotEmpty) return false;

    // ❌ DO NOT SHOW inside thread / realtime / activity
    if (currentPath.contains('/thread/') ||
        currentPath.contains('/realtime') ||
        currentPath.contains('/activity')) {
      return false;
    }

    final data = _mapOf(item['data']);
    final attention = _stringOf(data['attention']).toUpperCase();
    if (attention != 'INTERRUPT') return false;

    final type = _stringOf(item['type']).toUpperCase();
    final communicationType =
        _stringOf(data['communicationType']).toUpperCase();

    final isLive =
        type == 'LIVE' || communicationType == 'LIVE';

    if (!isLive) return false;

    return true;
  }

  Future<void> _joinCurrent() async {
    final item = _incoming;
    if (item == null) return;

    final repo = NotificationsRepository(ref.read(dioProvider));

    final id = _stringOf(item['id']);
    final data = _mapOf(item['data']);

    final sessionId = _stringOf(data['sessionId']);
    final threadId = _stringOf(data['threadId']);
    final spaceId = _stringOf(data['spaceId']);

    try {
      if (sessionId.isNotEmpty) {
        await ref
            .read(realtimeControllerProvider.notifier)
            .join(sessionId);
      }
      if (id.isNotEmpty) {
        await repo.markRead(id);
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _incoming = null;
    });

    // ✅ ALWAYS return to correspondence first
    if (threadId.isNotEmpty && spaceId.isNotEmpty) {
      context.go('/me/correspondence/$spaceId/thread/$threadId');
      return;
    }

    if (sessionId.isNotEmpty) {
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

    final data = _mapOf(item['data']);
    final actor = _mapOf(item['actor']);

    final actorName = _firstNonEmpty([
      _stringOf(actor['displayName']),
      _stringOf(actor['handle']),
      'Someone',
    ]);

    final mode = _stringOf(data['mode']).toLowerCase();
    final contextName = _firstNonEmpty([
      _stringOf(data['contextName']),
      'this conversation',
    ]);

    final title = mode == 'video'
        ? '$actorName started a video call'
        : '$actorName started an audio call';

    final body = 'Live is active in $contextName.';

    return Stack(
      children: [
        widget.child,

        /// 🔒 block background interaction
        Positioned.fill(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),
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
                          mode == 'video' ? 'Video live' : 'Audio live',
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        Text(actorName, style: AuraText.title),
                        const SizedBox(height: AuraSpace.s8),
                        Text(
                          title,
                          style: AuraText.body
                              .copyWith(fontWeight: FontWeight.w700),
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
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return {};
}

String _stringOf(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _firstNonEmpty(List<String> values) {
  for (final v in values) {
    if (v.trim().isNotEmpty) return v.trim();
  }
  return '';
}