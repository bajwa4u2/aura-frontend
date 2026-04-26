import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/communication/communication_resolver.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../updates/providers.dart';
import '../application/realtime_providers.dart';

class AuraIncomingLiveLayer extends ConsumerStatefulWidget {
  const AuraIncomingLiveLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuraIncomingLiveLayer> createState() =>
      _AuraIncomingLiveLayerState();
}

class _AuraIncomingLiveLayerState extends ConsumerState<AuraIncomingLiveLayer> {
  static const _resolver = CommunicationResolver();
  final Set<String> _dismissedIds = <String>{};
  final Set<String> _dismissedSessionIds = <String>{};
  bool _joining = false;

  bool _isInterruptCandidate(Map<String, dynamic> item, String currentPath) {
    final id = _stringOf(item['id']);
    if (id.isEmpty || _dismissedIds.contains(id)) return false;

    final data = _mapOf(item['data']);
    final sessionId = _firstNonEmpty([
      _stringOf(data['sessionId']),
      _stringOf(item['sessionId']),
    ]);
    if (sessionId.isNotEmpty && _dismissedSessionIds.contains(sessionId)) return false;
    if (_stringOf(item['readAt']).isNotEmpty) return false;

    if (currentPath.contains('/thread/') ||
        currentPath.contains('/realtime') ||
        currentPath.contains('/live') ||
        currentPath.contains('/activity')) {
      return false;
    }

    final attention = _stringOf(data['attention']).toUpperCase();
    if (attention != 'INTERRUPT') return false;

    final type = _stringOf(item['type']).toUpperCase();
    final communicationType = _stringOf(data['communicationType']).toUpperCase();
    return type == 'LIVE' || communicationType == 'LIVE';
  }

  Map<String, dynamic>? _currentIncoming(
    String currentPath,
    List<Map<String, dynamic>> items,
  ) {
    for (final item in items) {
      if (_isInterruptCandidate(item, currentPath)) {
        return item;
      }
    }
    return null;
  }

  Future<void> _joinCurrent(Map<String, dynamic> item) async {
    if (_joining) return;

    final data = _mapOf(item['data']);
    final target = _resolver.resolveFromPayload({...item, ...data});
    final sessionId = _firstNonEmpty([
      _stringOf(data['sessionId']),
      target.sessionId ?? '',
    ]);

    if (sessionId.isEmpty) return;

    setState(() {
      _joining = true;
    });

    final id = _stringOf(item['id']);
    _dismissedSessionIds.add(sessionId);
    try {
      await ref.read(realtimeControllerProvider.notifier).join(sessionId);
      if (id.isNotEmpty) {
        await ref.read(notificationsControllerProvider.notifier).markRead(id);
      }

      context.go(_resolver.resolveRoute(target));
    } catch (_) {
      _dismissedSessionIds.remove(sessionId);
      // let user try again
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  void _dismissCurrent(Map<String, dynamic> item) {
    final id = _stringOf(item['id']);
    if (id.isNotEmpty) {
      _dismissedIds.add(id);
    }
    final sessionId = _firstNonEmpty([
      _stringOf(_mapOf(item['data'])['sessionId']),
      _stringOf(item['sessionId']),
    ]);
    if (sessionId.isNotEmpty) {
      _dismissedSessionIds.add(sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsControllerProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final item = _currentIncoming(currentPath, notifications.items);
    if (item == null) return widget.child;

    final data = _mapOf(item['data']);
    final actor = _mapOf(item['actor']);

    final actorName = _firstNonEmpty([
      _stringOf(actor['displayName']),
      _stringOf(actor['handle']),
      'Someone',
    ]);

    final target = _resolver.resolveFromPayload({...item, ...data});
    final mode = _firstNonEmpty([
      _stringOf(data['mediaMode']),
      _stringOf(data['mode']),
      target.mode ?? '',
    ]).toLowerCase();
    final contextName = _firstNonEmpty([
      target.context ?? '',
      _stringOf(data['contextName']),
      'this conversation',
    ]);
    final ownerType = _stringOf(data['ownerType']).toUpperCase();

    final title = ownerType == 'SPACE'
        ? '${mode == 'video' ? 'Video' : 'Audio'} is live in $contextName'
        : mode == 'video'
            ? '$actorName started a video call'
            : '$actorName started an audio call';

    final body = ownerType == 'SPACE'
        ? 'Join from inside the space.'
        : 'Live is active in $contextName.';

    return Stack(
      children: [
        widget.child,
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
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        Text(body, style: AuraText.body),
                        const SizedBox(height: AuraSpace.s20),
                        Row(
                          children: [
                            Expanded(
                              child: AuraSecondaryButton(
                                label: 'Dismiss',
                                onPressed: _joining ? null : () => _dismissCurrent(item),
                              ),
                            ),
                            const SizedBox(width: AuraSpace.s12),
                            Expanded(
                              child: AuraPrimaryButton(
                                label: _joining ? 'Joining...' : 'Join',
                                onPressed: _joining ? null : () => _joinCurrent(item),
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
  if (value is Map) return value.map((key, val) => MapEntry(key.toString(), val));
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
