import 'package:flutter/material.dart';

enum CommunicationOwner {
  thread,
  space,
  spaceLiveRoom,
  standaloneRealtime,
}

class CommunicationTarget {
  final CommunicationOwner owner;
  final String? threadId;
  final String? spaceId;
  final String? sessionId;

  const CommunicationTarget({
    required this.owner,
    this.threadId,
    this.spaceId,
    this.sessionId,
  });
}

class CommunicationResolver {
  const CommunicationResolver();

  CommunicationTarget resolveFromPayload(Map<String, dynamic> payload) {
    final threadId = _pick(payload, ['threadId', 'thread_id']);
    final spaceId = _pick(payload, ['spaceId', 'space_id']);
    final sessionId = _pick(payload, ['sessionId', 'session_id', 'id']);

    final surfaceType =
        (payload['surfaceType'] ?? payload['surface_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (threadId.isNotEmpty) {
      return CommunicationTarget(
        owner: CommunicationOwner.thread,
        threadId: threadId,
        spaceId: spaceId,
        sessionId: sessionId,
      );
    }

    if (surfaceType == 'space' && spaceId.isNotEmpty) {
      return CommunicationTarget(
        owner: CommunicationOwner.space,
        spaceId: spaceId,
        sessionId: sessionId,
      );
    }

    return CommunicationTarget(
      owner: CommunicationOwner.standaloneRealtime,
      sessionId: sessionId,
    );
  }

  String resolveRoute(CommunicationTarget target) {
    switch (target.owner) {
      case CommunicationOwner.thread:
        final space = (target.spaceId ?? '').trim();
        final thread = (target.threadId ?? '').trim();
        return '/me/correspondence/$space/thread/$thread';

      case CommunicationOwner.space:
        return '/me/correspondence/${(target.spaceId ?? '').trim()}';

      case CommunicationOwner.spaceLiveRoom:
        return '/space-live/${(target.spaceId ?? '').trim()}';

      case CommunicationOwner.standaloneRealtime:
        return '/realtime/${(target.sessionId ?? '').trim()}';
    }
  }

  String _pick(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = (map[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}
