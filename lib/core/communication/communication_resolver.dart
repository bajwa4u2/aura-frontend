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
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = (payload[k] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    // shallow
    String threadId = pick(['threadId','thread_id']);
    String spaceId  = pick(['spaceId','space_id','surfaceId','surface_id']);
    String sessionId= pick(['sessionId','session_id','id']);

    final surfaceType =
        (payload['surfaceType'] ?? payload['surface_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    // nested session support (CRITICAL)
    final session = (payload['session'] is Map)
        ? Map<String, dynamic>.from(payload['session'])
        : <String, dynamic>{};

    final metadata = (session['metadata'] is Map)
        ? Map<String, dynamic>.from(session['metadata'])
        : <String, dynamic>{};

    if (threadId.isEmpty) {
      threadId = (metadata['threadId'] ?? metadata['thread_id'] ?? '')
          .toString()
          .trim();
    }

    if (spaceId.isEmpty) {
      final sType = (session['surfaceType'] ?? '').toString().toLowerCase();
      final sId   = (session['surfaceId'] ?? '').toString().trim();
      if (sType == 'space' && sId.isNotEmpty) {
        spaceId = sId;
      }
    }

    if (sessionId.isEmpty) {
      sessionId = (session['id'] ?? session['sessionId'] ?? '')
          .toString()
          .trim();
    }

    // decision
    if (threadId.isNotEmpty) {
      return CommunicationTarget(
        owner: CommunicationOwner.thread,
        threadId: threadId,
        spaceId: spaceId,
        sessionId: sessionId,
      );
    }

    if ((surfaceType == 'space' || (session['surfaceType'] ?? '').toString().toLowerCase() == 'space')
        && spaceId.isNotEmpty) {
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
        return '/me/correspondence/${target.spaceId ?? ''}/thread/${target.threadId ?? ''}';
      case CommunicationOwner.space:
        return '/me/correspondence/${target.spaceId ?? ''}';
      case CommunicationOwner.spaceLiveRoom:
        return '/space-live/${target.spaceId ?? ''}';
      case CommunicationOwner.standaloneRealtime:
        return '/realtime/${target.sessionId ?? ''}';
    }
  }
}
