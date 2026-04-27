import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/communication/communication_resolver.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
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
    if (sessionId.isNotEmpty && _dismissedSessionIds.contains(sessionId)) {
      return false;
    }
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
    final communicationType = _stringOf(
      data['communicationType'],
    ).toUpperCase();
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

    final router = GoRouter.of(context);
    final route = _resolver.resolveRoute(target);

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

      if (!mounted) return;
      router.go(route);
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
    setState(() {});
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

    final isVideo = mode == 'video';

    return Stack(
      children: [
        widget.child,
        // Blurred full-screen backdrop
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    const Color(0xFF0D1520).withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Call UI
        Positioned.fill(
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // Call type label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s6,
                  ),
                  decoration: BoxDecoration(
                    color: isVideo
                        ? AuraSurface.accentSoft
                        : const Color(0x1A3D9B4F),
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                    border: Border.all(
                      color: isVideo
                          ? AuraSurface.accent.withValues(alpha: 0.35)
                          : const Color(0x3A3D9B4F),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        size: 14,
                        color: isVideo
                            ? AuraSurface.accentText
                            : AuraSurface.goodInk,
                      ),
                      const SizedBox(width: AuraSpace.s6),
                      Text(
                        isVideo ? 'Incoming video call' : 'Incoming audio call',
                        style: AuraText.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isVideo
                              ? AuraSurface.accentText
                              : AuraSurface.goodInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s28),
                // Caller avatar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isVideo
                          ? AuraSurface.accent.withValues(alpha: 0.45)
                          : AuraSurface.goodInk.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isVideo ? AuraSurface.accent : AuraSurface.goodInk)
                            .withValues(alpha: 0.25),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: AuraAvatar(name: actorName, size: 96),
                ),
                const SizedBox(height: AuraSpace.s20),
                // Caller name
                Text(
                  actorName,
                  style: AuraText.headline.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AuraSpace.s8),
                // Context
                Text(
                  title,
                  style: AuraText.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 2),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Dismiss
                      Column(
                        children: [
                          _CallCircleButton(
                            icon: Icons.call_end_rounded,
                            color: AuraSurface.dangerInk,
                            background: AuraSurface.dangerBg,
                            size: 68,
                            onTap: _joining ? null : () => _dismissCurrent(item),
                          ),
                          const SizedBox(height: AuraSpace.s10),
                          Text(
                            'Dismiss',
                            style: AuraText.small.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Accept
                      Column(
                        children: [
                          _CallCircleButton(
                            icon: isVideo
                                ? Icons.videocam_rounded
                                : Icons.call_rounded,
                            color: Colors.white,
                            background: isVideo
                                ? AuraSurface.accent
                                : AuraSurface.goodInk,
                            size: 68,
                            onTap: _joining ? null : () => _joinCurrent(item),
                            busy: _joining,
                          ),
                          const SizedBox(height: AuraSpace.s10),
                          Text(
                            _joining ? 'Joining...' : 'Accept',
                            style: AuraText.small.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CallCircleButton extends StatelessWidget {
  const _CallCircleButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.size,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: background.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: busy
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, size: size * 0.38, color: color),
        ),
      ),
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
