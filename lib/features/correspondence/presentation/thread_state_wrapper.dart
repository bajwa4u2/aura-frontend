import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String? _lastHydratedSessionId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bindLiveAwareness);
  }

  Future<void> _bindLiveAwareness() async {
    final live = ref.read(correspondenceLiveServiceProvider);
    await live.joinThread(widget.threadId);

    _subscription = live.events.listen((event) {
      if (!_eventTargetsThread(event, widget.threadId)) return;

      final sessionId = _pickSessionId(event);
      if (sessionId.isNotEmpty && sessionId != _lastHydratedSessionId) {
        _lastHydratedSessionId = sessionId;
        unawaited(ref.read(realtimeControllerProvider.notifier).hydrateSession(sessionId));
        return;
      }

      if (event.name == 'session:removed' || event.name == 'realtime:removed') {
        unawaited(ref.read(realtimeControllerProvider.notifier).leave());
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(ref.read(correspondenceLiveServiceProvider).leaveThread(widget.threadId));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThreadScreen(threadId: widget.threadId);
  }
}

bool _eventTargetsThread(
  CorrespondenceLiveEvent event,
  String threadId,
) {
  final payload = event.payload;
  final normalizedThreadId = threadId.trim();
  if (normalizedThreadId.isEmpty) return false;

  final directThreadId = _pickString(payload, const ['threadId', 'thread_id']);
  if (directThreadId.isNotEmpty && directThreadId == normalizedThreadId) return true;

  final metadataThreadId = _pickNested(payload, const [
    ['metadata', 'threadId'],
    ['meta', 'threadId'],
    ['session', 'metadata', 'threadId'],
    ['session', 'meta', 'threadId'],
    ['live', 'threadId'],
    ['realtime', 'threadId'],
  ]);
  if (metadataThreadId.isNotEmpty && metadataThreadId == normalizedThreadId) return true;

  final surfaceType = _pickString(payload, const ['surfaceType', 'surface_type']).toUpperCase();
  final surfaceId = _pickString(payload, const ['surfaceId', 'surface_id']);
  if (surfaceType == 'DM' && surfaceId.isNotEmpty && surfaceId == normalizedThreadId) {
    return true;
  }

  return event.matchesThread(normalizedThreadId);
}

String _pickSessionId(CorrespondenceLiveEvent event) {
  final payload = event.payload;
  final direct = _pickString(payload, const ['sessionId', 'id']);
  if (direct.isNotEmpty) return direct;
  return _pickNested(payload, const [
    ['session', 'id'],
    ['live', 'sessionId'],
    ['realtime', 'sessionId'],
    ['activeSession', 'id'],
  ]);
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
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
    final text = (current ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
