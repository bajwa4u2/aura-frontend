import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/realtime/application/realtime_providers.dart';
import '../../features/realtime/domain/realtime_state.dart';
import '_call_presence_stub.dart'
    if (dart.library.html) '_call_presence_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRESENCE STATE
// ─────────────────────────────────────────────────────────────────────────────

/// Snapshot of a call that is active in a different browser tab.
class CallPresenceState {
  const CallPresenceState({
    required this.sessionId,
    required this.kind,
    required this.startedAt,
    required this.participantCount,
    required this.windowId,
    required this.lastHeartbeat,
    required this.micOn,
    required this.cameraOn,
  });

  final String sessionId;
  final String kind; // 'audio' | 'video'
  final DateTime? startedAt;
  final int participantCount;
  final String windowId; // source tab/window id
  final DateTime lastHeartbeat;
  final bool micOn;
  final bool cameraOn;

  bool get isVideo => kind == 'video';
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// Monitors and broadcasts call presence across browser tabs via BroadcastChannel.
///
/// - In the **call window**: watches [realtimeControllerProvider] and sends a
///   heartbeat every [_kHeartbeatInterval] while the call is active.
/// - In the **messages tab**: receives heartbeats and updates [state]; shows
///   [FloatingCallWidget] even though the local controller is idle.
/// - Both behaviors run simultaneously; each tab ignores its own messages.
final callPresenceBridgeProvider =
    StateNotifierProvider<CallPresenceBridgeNotifier, CallPresenceState?>(
  (ref) {
    final notifier = CallPresenceBridgeNotifier();

    // When a remote tab sends `request-end`, execute leave on the local controller
    // (this only fires in the call-window tab where the controller IS joined).
    notifier.onRequestEnd = () {
      if (ref.read(realtimeControllerProvider).isJoined) {
        ref.read(realtimeControllerProvider.notifier).leave();
      }
    };

    // Mirror local realtime state changes → start/stop broadcasting.
    ref.listen<RealtimeState>(
      realtimeControllerProvider,
      (_, next) => notifier._onRealtimeStateChanged(next),
      fireImmediately: true,
    );

    return notifier;
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class CallPresenceBridgeNotifier extends StateNotifier<CallPresenceState?> {
  CallPresenceBridgeNotifier() : super(null) {
    initPresenceChannel(_kChannel, _onMessage);
    registerWindowUnloadCallback(_onWindowUnload);
  }

  static const _kChannel = 'aura_call_presence';
  static const _kHeartbeatInterval = Duration(seconds: 3);
  // If no heartbeat in this window, the external call tab was likely closed.
  static const _kExpiryTimeout = Duration(seconds: 10);

  // Unique per-tab so we can discard our own reflected messages.
  final String _windowId =
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  Timer? _heartbeatTimer;
  Timer? _expiryTimer;
  RealtimeState? _lastRealtime;

  /// Set by the provider to delegate `request-end` into the local controller.
  void Function()? onRequestEnd;

  // ── Internal: react to local realtime controller ─────────────────────────

  void _onRealtimeStateChanged(RealtimeState next) {
    _lastRealtime = next;
    if (next.isJoined) {
      _startBroadcasting(next);
    } else {
      final wasActive = _heartbeatTimer?.isActive ?? false;
      _stopBroadcasting();
      if (wasActive) {
        // Broadcast a clean ended message so remote tabs update immediately.
        _post({
          'type': 'call-ended',
          'sessionId': next.sessionId ?? '',
          'windowId': _windowId,
        });
      }
    }
  }

  // ── Broadcasting (call window side) ──────────────────────────────────────

  void _startBroadcasting(RealtimeState s) {
    _stopBroadcasting();
    _postHeartbeat(s); // immediate
    _heartbeatTimer =
        Timer.periodic(_kHeartbeatInterval, (_) => _postHeartbeat(_lastRealtime));
  }

  void _stopBroadcasting() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _postHeartbeat(RealtimeState? s) {
    if (s == null || !s.isJoined) return;
    _post({
      'type': 'call-heartbeat',
      'sessionId': s.sessionId ?? '',
      'kind': s.callMode == 'video' ? 'video' : 'audio',
      'startedAt': s.session?.startedAt?.toIso8601String(),
      'participantCount': s.participants.length,
      'windowId': _windowId,
      'micOn': s.microphoneEnabled,
      'cameraOn': s.cameraEnabled,
    });
  }

  // ── Receiving (messages tab side) ────────────────────────────────────────

  void _onMessage(Map<String, dynamic> msg) {
    // Ignore reflections of our own messages.
    if ((msg['windowId'] as String?) == _windowId) return;

    switch (msg['type'] as String?) {
      case 'call-heartbeat':
        _handleHeartbeat(msg);
      case 'call-ended':
        _handleCallEnded();
      case 'request-end':
        onRequestEnd?.call();
    }
  }

  void _handleHeartbeat(Map<String, dynamic> msg) {
    // Reset expiry timer — window is still alive.
    _expiryTimer?.cancel();
    _expiryTimer = Timer(_kExpiryTimeout, _handleExpiry);

    final startedAtStr = msg['startedAt'] as String?;
    state = CallPresenceState(
      sessionId: (msg['sessionId'] as String?) ?? '',
      kind: (msg['kind'] as String?) ?? 'audio',
      startedAt:
          startedAtStr != null ? DateTime.tryParse(startedAtStr) : null,
      participantCount: (msg['participantCount'] as num?)?.toInt() ?? 0,
      windowId: (msg['windowId'] as String?) ?? '',
      lastHeartbeat: DateTime.now(),
      micOn: (msg['micOn'] as bool?) ?? true,
      cameraOn: (msg['cameraOn'] as bool?) ?? false,
    );
  }

  void _handleCallEnded() {
    _expiryTimer?.cancel();
    state = null;
  }

  void _handleExpiry() {
    // No heartbeat for _kExpiryTimeout — assume the call window was closed.
    state = null;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Broadcast a `request-end` to the call window so it can call leave().
  void broadcastRequestEnd(String sessionId) {
    _post({
      'type': 'request-end',
      'sessionId': sessionId,
      'windowId': _windowId,
    });
  }

  // ── Unload / dispose ─────────────────────────────────────────────────────

  void _onWindowUnload() {
    // Best-effort: if the call is active, notify other tabs before we die.
    if (_heartbeatTimer?.isActive == true &&
        _lastRealtime?.isJoined == true) {
      _post({
        'type': 'call-ended',
        'sessionId': _lastRealtime?.sessionId ?? '',
        'windowId': _windowId,
      });
    }
  }

  @override
  void dispose() {
    _stopBroadcasting();
    _expiryTimer?.cancel();
    closePresenceChannel();
    super.dispose();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _post(Map<String, dynamic> data) => postPresenceMessage(data);
}
