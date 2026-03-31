import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../realtime/application/realtime_providers.dart';
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
  String? _lastSessionId;
  bool _syncing = false;
  bool _postFrameSyncQueued = false;
  String? _joinedSpaceId;

  String _currentSpaceId() {
    try {
      return GoRouterState.of(context).pathParameters['spaceId']?.trim() ?? '';
    } catch (_) {
      return '';
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

    await _syncFromController();

    _subscription = live.events.listen((event) {
      if (!_targetsThreadOrSpace(
        event,
        threadId: widget.threadId,
        spaceId: _currentSpaceId(),
      )) {
        return;
      }

      final sessionId = _extractSessionId(event);
      if (sessionId.isNotEmpty && sessionId != _lastSessionId) {
        _lastSessionId = sessionId;
        unawaited(
          ref.read(realtimeControllerProvider.notifier).hydrateSession(sessionId),
        );
      }

      if (event.name == 'session:removed' || event.name == 'realtime:removed') {
        unawaited(ref.read(realtimeControllerProvider.notifier).leave());
      }

      unawaited(_syncFromController());
    });
  }

  Future<void> _syncFromController() async {
    if (!mounted || _syncing) return;
    _syncing = true;

    try {
      final notifier = ref.read(realtimeControllerProvider.notifier);
      final liveState = ref.read(realtimeControllerProvider);
      final spaceId = _currentSpaceId();

      final activeSessionId = notifier.activeSessionIdForCorrespondence(
        threadId: widget.threadId,
        spaceId: spaceId.isEmpty ? null : spaceId,
      );

      if (activeSessionId != null &&
          activeSessionId.isNotEmpty &&
          activeSessionId != _lastSessionId) {
        _lastSessionId = activeSessionId;
        await notifier.hydrateSession(activeSessionId);
        return;
      }

      final session = liveState.session;
      if (session != null && session.isActive) {
        final sessionType = session.surfaceType.name.trim().toLowerCase();
        final sessionSurfaceId = (session.surfaceId ?? '').trim();
        final matchesThread =
            sessionType == 'dm' && sessionSurfaceId == widget.threadId.trim();
        final matchesSpace =
            sessionType == 'space' &&
            spaceId.isNotEmpty &&
            sessionSurfaceId == spaceId;

        if (matchesThread || matchesSpace) {
          final sessionId = (liveState.sessionId ?? session.id).trim();
          if (sessionId.isNotEmpty && sessionId != _lastSessionId) {
            _lastSessionId = sessionId;
            await notifier.hydrateSession(sessionId);
          }
        }
      }
    } finally {
      _syncing = false;
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
    if (!_postFrameSyncQueued) {
      _postFrameSyncQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _postFrameSyncQueued = false;
        unawaited(_syncFromController());
      });
    }

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
  if (surfaceId.isNotEmpty &&
      (surfaceId == normalizedThreadId ||
          (normalizedSpaceId.isNotEmpty && surfaceId == normalizedSpaceId))) {
    return true;
  }

  if (event.matchesThread(normalizedThreadId)) return true;
  if (normalizedSpaceId.isNotEmpty && event.matchesSpace(normalizedSpaceId)) {
    return true;
  }

  final sessionId = _extractSessionId(event);
  if (sessionId.isNotEmpty &&
      (event.name.startsWith('session:') || event.name.startsWith('realtime:'))) {
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
