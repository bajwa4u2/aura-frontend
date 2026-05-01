import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/call_presence_bridge.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../realtime/domain/realtime_state.dart';
import '../data/correspondence_live_service.dart';
import 'thread_screen.dart';

class ThreadStateWrapper extends ConsumerStatefulWidget {
  const ThreadStateWrapper({
    super.key,
    required this.threadId,
  });

  final String threadId;

  @override
  ConsumerState<ThreadStateWrapper> createState() => _ThreadStateWrapperState();
}

class _ThreadStateWrapperState extends ConsumerState<ThreadStateWrapper> {
  StreamSubscription<CorrespondenceLiveEvent>? _subscription;
  String? _lastHydratedSessionId;
  String? _joinedSpaceId;
  bool _handledJoinQuery = false;

  String _currentSpaceId() {
    try {
      return GoRouterState.of(context).pathParameters['spaceId']?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _querySessionId() {
    try {
      final state = GoRouterState.of(context);
      final fromPath = state.pathParameters['sessionId']?.trim() ?? '';
      if (fromPath.isNotEmpty) return fromPath;
      return state.uri.queryParameters['sessionId']?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  bool _shouldJoinFromRoute() {
    try {
      final state = GoRouterState.of(context);
      final fromPath = state.pathParameters['sessionId']?.trim() ?? '';
      if (fromPath.isNotEmpty) return false;
      final value = state.uri.queryParameters['join']?.trim().toLowerCase() ?? '';
      return value == '1' || value == 'true' || value == 'yes';
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_bindLive);
  }

  Future<void> _bindLive() async {
    final live = ref.read(correspondenceLiveServiceProvider);
    final spaceId = _currentSpaceId();

    await live.joinThread(widget.threadId);
    if (spaceId.isNotEmpty) {
      await live.joinSpace(spaceId);
      _joinedSpaceId = spaceId;
    }

    await _maybeJoinFromRoute();

    _subscription = live.events.listen((event) {
      if (!_targetsThreadOrSpace(
        event,
        threadId: widget.threadId,
        spaceId: _currentSpaceId(),
      )) {
        return;
      }

      // Only invalidate thread + message providers on actual message events.
      // Session participant events (join/leave/resume), read-receipt updates,
      // and invite events do not change message content — refreshing on them
      // causes unnecessary reload storms during active calls.
      if (event.name == 'thread:message.created' ||
          event.name == 'thread:message.updated' ||
          event.name == 'thread:message.deleted') {
        _refreshThreadSurface();
      }

      unawaited(_hydrateFromEvent(event));
    });
  }

  void _refreshThreadSurface() {
    ref.invalidate(threadDetailProvider(widget.threadId));
    ref.invalidate(messagesProvider(widget.threadId));
  }

  Future<void> _hydrateFromEvent(CorrespondenceLiveEvent event) async {
    final notifier = ref.read(realtimeControllerProvider.notifier);
    final sessionId = _extractSessionId(event);

    if (event.name == 'session:removed' ||
        event.name == 'realtime:removed' ||
        event.name == 'call:terminal') {
      _lastHydratedSessionId = null;
      await notifier.leave();
      _refreshThreadSurface();
      return;
    }

    final liveState = ref.read(realtimeControllerProvider);
    final currentSessionId = (liveState.sessionId ?? liveState.session?.id ?? '').trim();

    if (sessionId.isNotEmpty &&
        sessionId != _lastHydratedSessionId &&
        currentSessionId != sessionId) {
      _lastHydratedSessionId = sessionId;
      await notifier.hydrateSession(sessionId);
    }

    await _maybeJoinFromRoute();
  }

  Future<void> _maybeJoinFromRoute() async {
    if (!mounted || _handledJoinQuery || !_shouldJoinFromRoute()) return;

    final sessionId = _querySessionId();
    if (sessionId.isEmpty) return;

    _handledJoinQuery = true;
    _lastHydratedSessionId = sessionId;

    final notifier = ref.read(realtimeControllerProvider.notifier);
    final liveState = ref.read(realtimeControllerProvider);
    final currentSessionId = (liveState.sessionId ?? liveState.session?.id ?? '').trim();
    final alreadyJoined =
        liveState.joinState.name.toLowerCase() == 'joined' && currentSessionId == sessionId;
    final alreadyJoining =
        liveState.joinState.name.toLowerCase() == 'joining' && currentSessionId == sessionId;

    if (alreadyJoined || alreadyJoining) return;

    try {
      await notifier.join(sessionId);
    } catch (_) {
      // Keep the thread stable even if live join fails.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(
      ref.read(correspondenceLiveServiceProvider).leaveThread(widget.threadId),
    );
    final spaceId = _joinedSpaceId;
    if (spaceId != null && spaceId.isNotEmpty) {
      unawaited(
        ref.read(correspondenceLiveServiceProvider).leaveSpace(spaceId),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Path 1: same-tab call end.
    // The realtime controller transitions joined → not-joined (e.g. last
    // participant left → _terminateSession called via session:participant.left).
    ref.listen<RealtimeState>(
      realtimeControllerProvider,
      (previous, next) {
        if ((previous?.isJoined ?? false) && !next.isJoined) {
          _refreshThreadSurface();
        }
      },
    );

    // Path 2: cross-tab call end (popup window).
    // The backend never sends live.ended via socket (attentionPolicy: NEVER).
    // call:terminal only goes to INVITED/LEFT participants, not joined ones.
    // The only cross-tab signal is the BroadcastChannel `call-ended` message
    // broadcast by callPresenceBridgeProvider when the popup ends the call.
    // When the bridge state drops non-null → null, the call is confirmed gone:
    //   • clearLocalSession() evicts the stale session reference in this tab's
    //     controller that _threadResolvedSessionId falls back to.
    //   • _refreshThreadSurface() refetches thread detail so liveSessionId is
    //     gone from the thread payload too.
    ref.listen<CallPresenceState?>(
      callPresenceBridgeProvider,
      (previous, next) {
        if (previous != null && next == null) {
          _lastHydratedSessionId = null;
          ref.read(realtimeControllerProvider.notifier).clearLocalSession();
          _refreshThreadSurface();
        }
      },
    );

    return ThreadScreen(threadId: widget.threadId);
  }
}


bool _targetsThreadOrSpace(
  CorrespondenceLiveEvent event, {
  required String threadId,
  required String spaceId,
}) {
  final payload = event.payload;
  final normalizedThreadId = threadId.trim();
  final normalizedSpaceId = spaceId.trim();

  final directThreadId = _pick(payload, const ['threadId', 'thread_id']);
  if (directThreadId.isNotEmpty && directThreadId == normalizedThreadId) {
    return true;
  }

  final directSpaceId = _pick(payload, const ['spaceId', 'space_id']);
  if (normalizedSpaceId.isNotEmpty &&
      directSpaceId.isNotEmpty &&
      directSpaceId == normalizedSpaceId) {
    return true;
  }

  final nestedThreadId = _pickNested(payload, const [
    ['metadata', 'threadId'],
    ['meta', 'threadId'],
    ['session', 'metadata', 'threadId'],
    ['session', 'meta', 'threadId'],
    ['live', 'threadId'],
    ['realtime', 'threadId'],
  ]);
  if (nestedThreadId.isNotEmpty && nestedThreadId == normalizedThreadId) {
    return true;
  }

  final nestedSpaceId = _pickNested(payload, const [
    ['metadata', 'spaceId'],
    ['meta', 'spaceId'],
    ['session', 'metadata', 'spaceId'],
    ['session', 'meta', 'spaceId'],
    ['live', 'spaceId'],
    ['realtime', 'spaceId'],
  ]);
  if (normalizedSpaceId.isNotEmpty &&
      nestedSpaceId.isNotEmpty &&
      nestedSpaceId == normalizedSpaceId) {
    return true;
  }

  final surfaceId = _pick(payload, const ['surfaceId', 'surface_id']);
  final surfaceType = _pick(payload, const ['surfaceType', 'surface_type']).toLowerCase();
  if (surfaceId.isNotEmpty) {
    if (surfaceType == 'space' && normalizedSpaceId.isNotEmpty && surfaceId == normalizedSpaceId) {
      return true;
    }
    if ((surfaceType == 'dm' || surfaceType == 'thread') && surfaceId == normalizedThreadId) {
      return true;
    }
  }

  if (event.matchesThread(normalizedThreadId)) return true;
  if (normalizedSpaceId.isNotEmpty && event.matchesSpace(normalizedSpaceId)) {
    return true;
  }

  return false;
}

String _extractSessionId(CorrespondenceLiveEvent event) {
  final payload = event.payload;

  final direct = _pick(payload, const ['sessionId', 'id']);
  if (direct.isNotEmpty) return direct;

  return _pickNested(payload, const [
    ['session', 'id'],
    ['live', 'sessionId'],
    ['realtime', 'sessionId'],
    ['activeSession', 'id'],
  ]);
}

String _pick(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _pickNested(Map<String, dynamic> map, List<List<String>> paths) {
  for (final path in paths) {
    dynamic current = map;
    for (final key in path) {
      if (current is! Map) {
        current = null;
        break;
      }
      current = current[key];
    }
    final value = (current ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}