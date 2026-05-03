import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/communication/communication_resolver.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../correspondence/data/correspondence_live_service.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../updates/incoming_call_bridge.dart';
import '../../updates/providers.dart';
import '../application/realtime_providers.dart';
import '../domain/realtime_state.dart';
import 'widgets/floating_call_widget.dart';

class AuraIncomingLiveLayer extends ConsumerStatefulWidget {
  const AuraIncomingLiveLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuraIncomingLiveLayer> createState() =>
      _AuraIncomingLiveLayerState();
}

class _AuraIncomingLiveLayerState extends ConsumerState<AuraIncomingLiveLayer>
    with SingleTickerProviderStateMixin {
  static const _resolver = CommunicationResolver();
  // Auto-dismiss after this long — long enough to be heard but avoids
  // the overlay persisting indefinitely if the backend never sends ENDED.
  static const _ringTimeout = Duration(seconds: 50);

  final Set<String> _dismissedIds = <String>{};
  final Set<String> _dismissedSessionIds = <String>{};
  bool _joining = false;
  String? _joinError;
  Timer? _ringTimer;
  String? _ringTimerNotificationId;

  // Pulse animation for the ringing avatar ring.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Ensure the main-namespace socket is connected as soon as the shell mounts
    // so call invites are delivered even when the user has not opened a thread
    // or space. ensureConnected() is idempotent and safe to call eagerly.
    Future.microtask(
      () => ref.read(correspondenceLiveServiceProvider).ensureConnected(),
    );
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Payload helpers ───────────────────────────────────────────────────────

  String _resolveKind(Map<String, dynamic> item) {
    final data = _mapOf(item['data']);
    return _firstNonEmpty([
      _stringOf(item['notificationKind']),
      _stringOf(item['type']),
      _stringOf(data['notificationKind']),
      _stringOf(data['communicationType']),
      _stringOf(data['type']),
    ]).toUpperCase();
  }

  String _resolveSessionId(Map<String, dynamic> item) {
    final data = _mapOf(item['data']);
    return _firstNonEmpty([
      _stringOf(data['realtimeSessionId']),
      _stringOf(data['sessionId']),
      _stringOf(item['realtimeSessionId']),
      _stringOf(item['sessionId']),
    ]);
  }

  String _resolveCallState(Map<String, dynamic> item) {
    final data = _mapOf(item['data']);
    return _firstNonEmpty([
      _stringOf(data['callState']),
      _stringOf(data['status']),
      _stringOf(data['state']),
      _stringOf(data['result']),
      _stringOf(item['callState']),
      _stringOf(item['status']),
      _stringOf(item['state']),
      _stringOf(item['result']),
    ]).toUpperCase();
  }

  bool _isTerminalCallItem(Map<String, dynamic> item) {
    final data = _mapOf(item['data']);
    final terminalValues = <String>{
      'MISSED',
      'ENDED',
      'DECLINED',
      'EXPIRED',
      'CANCELLED',
      'CANCELED',
      'FAILED',
      'TIMEOUT',
      'TIMED_OUT',
      'NO_ANSWER',
      'REJECTED',
      'COMPLETED',
      'CLOSED',
    };

    final stateCandidates = <String>[
      _resolveCallState(item),
      _stringOf(item['callStatus']).toUpperCase(),
      _stringOf(item['deliveryState']).toUpperCase(),
      _stringOf(data['callStatus']).toUpperCase(),
      _stringOf(data['deliveryState']).toUpperCase(),
      _stringOf(data['inviteStatus']).toUpperCase(),
    ];
    if (stateCandidates.any(terminalValues.contains)) return true;

    final searchable = <String>[
      _stringOf(item['title']),
      _stringOf(item['body']),
      _stringOf(item['message']),
      _stringOf(item['previewText']),
      _stringOf(data['title']),
      _stringOf(data['body']),
      _stringOf(data['message']),
      _stringOf(data['previewText']),
      _stringOf(data['summary']),
    ].join(' ').toLowerCase();

    return searchable.contains('missed a call') ||
        searchable.contains('missed call') ||
        searchable.contains('call ended') ||
        searchable.contains('ended a call') ||
        searchable.contains('call declined') ||
        searchable.contains('declined a call') ||
        searchable.contains('call expired') ||
        searchable.contains('call cancelled') ||
        searchable.contains('call canceled') ||
        searchable.contains('no answer');
  }

  bool _isCallKind(String kind) =>
      kind == 'LIVE' || kind == 'CALL' || kind == 'REALTIME';

  // ── Interrupt candidate logic ─────────────────────────────────────────────

  bool _isInterruptCandidate(
    Map<String, dynamic> item,
    String currentPath,
    RealtimeState liveState,
  ) {
    final id = _stringOf(item['id']);
    if (id.isEmpty || _dismissedIds.contains(id)) return false;

    final sessionId = _resolveSessionId(item);
    if (sessionId.isNotEmpty && _dismissedSessionIds.contains(sessionId)) {
      return false;
    }
    if (_stringOf(item['readAt']).isNotEmpty) return false;

    // Terminal/missed call notifications are history/toast items, never
    // interrupting call UI. Some backend payloads only expose this in text or
    // status fields, so use robust detection instead of trusting callState only.
    if (_isTerminalCallItem(item)) return false;

    // Suppress if the invite has already expired server-side.
    final data = _mapOf(item['data']);
    final expiresAtStr = _stringOf(data['expiresAt']);
    if (expiresAtStr.isNotEmpty) {
      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
        return false;
      }
    }

    // Already in a dedicated realtime room or live sub-route — suppress.
    if (currentPath.contains('/realtime') ||
        currentPath.contains('/live/') ||
        currentPath.contains('/activity')) {
      return false;
    }

    // Already joined this exact session — never re-interrupt regardless of route.
    if (liveState.isJoined &&
        sessionId.isNotEmpty &&
        liveState.sessionId == sessionId) {
      return false;
    }

    // Joined any call on a non-thread route — suppress the card so the PiP
    // widget is the only call UI visible.
    if (liveState.isJoined && !currentPath.contains('/thread/')) {
      return false;
    }

    // On any thread route: only suppress if we are already joined into this
    // exact session. A call from a different thread must still show the overlay.
    if (currentPath.contains('/thread/')) {
      final alreadyInThisSession = sessionId.isNotEmpty &&
          liveState.isJoined &&
          liveState.sessionId == sessionId;
      if (alreadyInThisSession) return false;
    }

    final attention = _stringOf(data['attention']).toUpperCase();
    if (attention != 'INTERRUPT') return false;

    final kind = _resolveKind(item);
    return _isCallKind(kind);
  }

  Map<String, dynamic>? _currentIncoming(
    String currentPath,
    List<Map<String, dynamic>> items,
    RealtimeState liveState,
  ) {
    for (final item in items) {
      if (_isInterruptCandidate(item, currentPath, liveState)) {
        return item;
      }
    }
    return null;
  }

  void _ensureRingTimer(Map<String, dynamic> item) {
    final id = _stringOf(item['id']);
    if (id == _ringTimerNotificationId) return;
    _ringTimer?.cancel();
    _ringTimerNotificationId = id;
    _ringTimer = Timer(_ringTimeout, () {
      if (!mounted) return;
      final sessionId = _resolveSessionId(item);
      if (id.isNotEmpty) _dismissedIds.add(id);
      if (sessionId.isNotEmpty) _dismissedSessionIds.add(sessionId);
      ref.read(incomingCallBridgeProvider.notifier).remove(id);
      if (id.isNotEmpty) {
        unawaited(
          ref.read(notificationsControllerProvider.notifier).markRead(id),
        );
      }
      setState(() => _joinError = null);
    });
  }

  void _cancelRingTimer() {
    _ringTimer?.cancel();
    _ringTimer = null;
    _ringTimerNotificationId = null;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _joinCurrent(Map<String, dynamic> item) async {
    if (_joining) return;

    final data = _mapOf(item['data']);
    final target = _resolver.resolveFromPayload({...item, ...data});
    final sessionId = _firstNonEmpty([
      _resolveSessionId(item),
      target.sessionId ?? '',
    ]);

    if (sessionId.isEmpty) return;

    _cancelRingTimer();
    final router = GoRouter.of(context);

    setState(() {
      _joining = true;
      _joinError = null;
    });

    final id = _stringOf(item['id']);
    _dismissedSessionIds.add(sessionId);
    try {
      await ref.read(realtimeControllerProvider.notifier).join(sessionId);
      ref.read(incomingCallBridgeProvider.notifier).remove(id);
      if (id.isNotEmpty) {
        await ref.read(notificationsControllerProvider.notifier).markRead(id);
      }

      if (!mounted) return;
      final returnTo = Uri.encodeComponent(GoRouterState.of(context).uri.toString());
      router.go('/realtime/$sessionId?returnTo=$returnTo');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final isExpired = msg.contains('invite_expired') ||
          msg.contains('session_closed') ||
          msg.contains('invite has expired');
      if (isExpired) {
        // Invite is no longer valid — dismiss the overlay silently.
        ref.read(incomingCallBridgeProvider.notifier).remove(id);
        if (mounted) {
          setState(() {
            _joinError = 'This call is no longer available.';
          });
        }
        // Auto-dismiss the expired error after a short delay.
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _dismissedIds.add(id);
            setState(() => _joinError = null);
          }
        });
      } else {
        // Transient join failure — let user retry or dismiss.
        _dismissedSessionIds.remove(sessionId);
        if (mounted) {
          setState(() {
            _joinError = 'Could not join the call. Check your connection.';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  Future<void> _retryJoin(Map<String, dynamic> item) async {
    setState(() => _joinError = null);
    await _joinCurrent(item);
  }

  Future<void> _declineCurrent(Map<String, dynamic> item) async {
    _cancelRingTimer();
    final id = _stringOf(item['id']);
    if (id.isNotEmpty) _dismissedIds.add(id);

    final sessionId = _resolveSessionId(item);
    if (sessionId.isNotEmpty) _dismissedSessionIds.add(sessionId);

    // Remove from socket bridge and dismiss overlay immediately.
    ref.read(incomingCallBridgeProvider.notifier).remove(id);
    if (mounted) setState(() => _joinError = null);

    // Authoritative decline: awaited so the backend reflects the decision.
    if (sessionId.isNotEmpty) {
      try {
        await ref.read(realtimeRepositoryProvider).declineInvite(sessionId);
      } catch (_) {
        // Local dismiss already applied; backend will clean up on session timeout.
      }
    }

    if (id.isNotEmpty) {
      try {
        await ref.read(notificationsControllerProvider.notifier).markRead(id);
      } catch (_) {}
    }
  }

  void _dismissError(Map<String, dynamic> item) {
    _cancelRingTimer();
    final id = _stringOf(item['id']);
    if (id.isNotEmpty) _dismissedIds.add(id);
    final sessionId = _resolveSessionId(item);
    if (sessionId.isNotEmpty) _dismissedSessionIds.add(sessionId);
    ref.read(incomingCallBridgeProvider.notifier).remove(id);
    setState(() => _joinError = null);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsControllerProvider);
    final bridgeItems = ref.watch(incomingCallBridgeProvider);
    final liveState = ref.watch(realtimeControllerProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    // Socket-first: bridge items precede poll items.
    // Deduplicate by sessionId so a poll item never shadows its bridge twin.
    final bridgeSessionIds = <String>{
      for (final b in bridgeItems)
        if (_resolveSessionId(b).isNotEmpty) _resolveSessionId(b),
    };
    final dedupedPollItems = notifications.items
        .where((n) {
          final sid = _resolveSessionId(n);
          return sid.isEmpty || !bridgeSessionIds.contains(sid);
        })
        .toList();
    final allItems = [...bridgeItems, ...dedupedPollItems];
    final item = _currentIncoming(currentPath, allItems, liveState);
    if (item == null) {
      _cancelRingTimer();
      if (!liveState.isJoined) return widget.child;
      // Active local call — keep PiP overlay mounted so the card persists
      // when the user navigates away from the /realtime screen.
      return Stack(        
        children: [
          widget.child,
          if (liveState.isJoined) const FloatingCallWidget(),
        ],
      );
    }

    _ensureRingTimer(item);

    final data = _mapOf(item['data']);
    final actor = _mapOf(item['actor']);

    final actorName = _firstNonEmpty([
      _stringOf(actor['displayName']),
      _stringOf(actor['handle']),
      'Someone',
    ]);

    final target = _resolver.resolveFromPayload({...item, ...data});
    final mode = _firstNonEmpty([
      _stringOf(data['callKind']),
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
    final ringLabel = isVideo ? 'Incoming video call' : 'Incoming audio call';

    return Stack(
      children: [
        widget.child,
        if (liveState.isJoined) const FloatingCallWidget(),
        Positioned(
          right: MediaQuery.of(context).size.width >= 700 ? AuraSpace.s20 : AuraSpace.s12,
          left: MediaQuery.of(context).size.width >= 700 ? null : AuraSpace.s12,
          bottom: MediaQuery.of(context).size.width >= 700 ? AuraSpace.s20 : AuraSpace.s12,
          child: SafeArea(
            child: _IncomingCallCard(
              actorName: actorName,
              title: title,
              ringLabel: ringLabel,
              isVideo: isVideo,
              joining: _joining,
              joinError: _joinError,
              pulseAnim: _pulseAnim,
              onAccept: _joining ? null : () => _joinCurrent(item),
              onDecline: _joining ? null : () => _declineCurrent(item),
              onDismissError: () => _dismissError(item),
              onRetry: () => _retryJoin(item),
            ),
          ),
        ),
      ],
    );
  }
}


class _IncomingCallCard extends StatelessWidget {
  const _IncomingCallCard({
    required this.actorName,
    required this.title,
    required this.ringLabel,
    required this.isVideo,
    required this.joining,
    required this.joinError,
    required this.pulseAnim,
    required this.onAccept,
    required this.onDecline,
    required this.onDismissError,
    required this.onRetry,
  });

  final String actorName;
  final String title;
  final String ringLabel;
  final bool isVideo;
  final bool joining;
  final String? joinError;
  final Animation<double> pulseAnim;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback onDismissError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ringColor = isVideo ? AuraSurface.accent : AuraSurface.goodInk;
    return Container(
      width: 360,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: const Color(0xF20D1520),
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: ringColor.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (context, child) {
                  final pulseOpacity = joining ? 0.0 : pulseAnim.value;
                  return Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor.withValues(alpha: 0.35 + pulseOpacity * 0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withValues(alpha: pulseOpacity * 0.26),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: AuraAvatar(name: actorName, size: 52),
                  );
                },
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          size: 15,
                          color: ringColor,
                        ),
                        const SizedBox(width: AuraSpace.s6),
                        Expanded(
                          child: Text(
                            ringLabel,
                            style: AuraText.small.copyWith(
                              color: ringColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      actorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.title.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AuraSpace.s2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (joinError != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s10),
              decoration: BoxDecoration(
                color: AuraSurface.dangerBg,
                borderRadius: BorderRadius.circular(AuraRadius.md),
                border: Border.all(color: AuraSurface.dangerInk.withValues(alpha: 0.35)),
              ),
              child: Text(
                joinError!,
                style: AuraText.small.copyWith(
                  color: AuraSurface.dangerInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.s14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (joinError != null) ...[
                _GhostCallButton(label: 'Dismiss', onTap: onDismissError),
                const SizedBox(width: AuraSpace.s10),
                _GhostCallButton(label: 'Retry', onTap: onRetry, accent: true),
              ] else ...[
                _CallCircleButton(
                  icon: Icons.call_end_rounded,
                  color: AuraSurface.dangerInk,
                  background: AuraSurface.dangerBg,
                  size: 48,
                  onTap: onDecline,
                ),
                const SizedBox(width: AuraSpace.s14),
                _CallCircleButton(
                  icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: Colors.white,
                  background: isVideo ? AuraSurface.accent : AuraSurface.goodInk,
                  size: 54,
                  onTap: onAccept,
                  busy: joining,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Call buttons ──────────────────────────────────────────────────────────────

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

class _GhostCallButton extends StatelessWidget {
  const _GhostCallButton({
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: accent
                ? AuraSurface.accent.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: accent
                  ? AuraSurface.accent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: accent ? AuraSurface.accentText : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Primitive helpers (module-private) ────────────────────────────────────────

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
