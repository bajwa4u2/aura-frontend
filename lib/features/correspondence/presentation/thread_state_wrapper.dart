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
  String? _lastSessionId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bindLive);
  }

  Future<void> _bindLive() async {
    final live = ref.read(correspondenceLiveServiceProvider);

    // join thread-level live channel
    await live.joinThread(widget.threadId);

    _subscription = live.events.listen((event) {
      if (!_targetsThread(event, widget.threadId)) return;

      final sessionId = _extractSessionId(event);

      if (sessionId.isNotEmpty && sessionId != _lastSessionId) {
        _lastSessionId = sessionId;
        ref.read(realtimeControllerProvider.notifier).hydrateSession(sessionId);
        return;
      }

      if (event.name == 'session:removed' || event.name == 'realtime:removed') {
        ref.read(realtimeControllerProvider.notifier).leave();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    ref.read(correspondenceLiveServiceProvider).leaveThread(widget.threadId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThreadScreen(threadId: widget.threadId);
  }
}

bool _targetsThread(CorrespondenceLiveEvent event, String threadId) {
  final payload = event.payload;

  final direct = _pick(payload, ['threadId', 'thread_id']);
  if (direct == threadId) return true;

  final nested = _pickNested(payload, [
    ['metadata', 'threadId'],
    ['session', 'metadata', 'threadId'],
    ['live', 'threadId'],
  ]);
  if (nested == threadId) return true;

  final surfaceId = _pick(payload, ['surfaceId', 'surface_id']);
  if (surfaceId == threadId) return true;

  return event.matchesThread(threadId);
}

String _extractSessionId(CorrespondenceLiveEvent event) {
  final payload = event.payload;

  final direct = _pick(payload, ['sessionId', 'id']);
  if (direct.isNotEmpty) return direct;

  return _pickNested(payload, [
    ['session', 'id'],
    ['live', 'sessionId'],
  ]);
}

String _pick(Map<String, dynamic> map, List<String> keys) {
  for (final k in keys) {
    final v = (map[k] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
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
