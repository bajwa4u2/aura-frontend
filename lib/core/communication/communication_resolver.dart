import 'package:flutter/material.dart';

enum CommunicationOwner {
  thread,
  space,
  standaloneRealtime,
  unknown,
}

class CommunicationTarget {
  final CommunicationOwner owner;
  final String? threadId;
  final String? spaceId;
  final String? sessionId;
  final String? deeplink;
  final String? context;
  final String? mode;
  final String? attention;

  const CommunicationTarget({
    required this.owner,
    this.threadId,
    this.spaceId,
    this.sessionId,
    this.deeplink,
    this.context,
    this.mode,
    this.attention,
  });

  bool get hasOwner => owner != CommunicationOwner.unknown;
  bool get isInline => (attention ?? '').toUpperCase() == 'INLINE';
}

class CommunicationResolver {
  const CommunicationResolver();

  CommunicationTarget resolveFromPayload(Map<String, dynamic> payload) {
    final session = _mapOf(payload['session']);
    final metadata = _mapOf(session['metadata']);
    final meta = _mapOf(payload['metadata']);

    final deeplink = _firstNonEmpty([
      _stringOf(payload['route']),
      _stringOf(payload['deeplink']),
      _stringOf(payload['link']),
      _stringOf(payload['url']),
      _stringOf(meta['route']),
      _stringOf(meta['deeplink']),
      _stringOf(metadata['route']),
      _stringOf(metadata['deeplink']),
    ]);

    final parsed = _parseDeeplink(deeplink);

    final threadId = _firstNonEmpty([
      _stringOf(payload['threadId']),
      _stringOf(payload['thread_id']),
      _stringOf(meta['threadId']),
      _stringOf(metadata['threadId']),
      parsed.threadId ?? '',
    ]);

    final spaceId = _firstNonEmpty([
      _stringOf(payload['spaceId']),
      _stringOf(payload['space_id']),
      _stringOf(meta['spaceId']),
      _stringOf(metadata['spaceId']),
      _stringOf(payload['surfaceType']).toUpperCase() == 'SPACE'
          ? _stringOf(payload['surfaceId'])
          : '',
      _stringOf(session['surfaceType']).toUpperCase() == 'SPACE'
          ? _stringOf(session['surfaceId'])
          : '',
      parsed.spaceId ?? '',
    ]);

    final sessionId = _firstNonEmpty([
      _stringOf(payload['sessionId']),
      _stringOf(payload['session_id']),
      _stringOf(session['id']),
      _stringOf(session['sessionId']),
      _stringOf(payload['id']),
    ]);

    final ownerType = _firstNonEmpty([
      _stringOf(payload['ownerType']).toUpperCase(),
      _stringOf(meta['ownerType']).toUpperCase(),
      _stringOf(metadata['ownerType']).toUpperCase(),
      parsed.ownerType ?? '',
    ]);

    final context = _firstNonEmpty([
      _stringOf(payload['context']).toUpperCase(),
      _stringOf(meta['context']).toUpperCase(),
      _stringOf(metadata['context']).toUpperCase(),
    ]);

    final mode = _firstNonEmpty([
      _stringOf(payload['mode']).toUpperCase(),
      _stringOf(meta['mode']).toUpperCase(),
      _stringOf(metadata['mode']).toUpperCase(),
    ]);

    final attention = _firstNonEmpty([
      _stringOf(payload['attention']).toUpperCase(),
      _stringOf(meta['attention']).toUpperCase(),
      _stringOf(metadata['attention']).toUpperCase(),
    ]);

    if (threadId.isNotEmpty) {
      return CommunicationTarget(
        owner: CommunicationOwner.thread,
        threadId: threadId,
        spaceId: spaceId.isEmpty ? null : spaceId,
        sessionId: sessionId.isEmpty ? null : sessionId,
        deeplink: deeplink.isEmpty ? null : deeplink,
        context: context.isEmpty ? 'THREAD' : context,
        mode: mode.isEmpty ? null : mode,
        attention: attention.isEmpty ? null : attention,
      );
    }

    if (spaceId.isNotEmpty) {
      return CommunicationTarget(
        owner: CommunicationOwner.space,
        spaceId: spaceId,
        sessionId: sessionId.isEmpty ? null : sessionId,
        deeplink: deeplink.isEmpty ? null : deeplink,
        context: context.isEmpty ? 'SPACE' : context,
        mode: mode.isEmpty ? null : mode,
        attention: attention.isEmpty ? null : attention,
      );
    }

    if ((ownerType == 'REALTIME' || context == 'STANDALONE') && deeplink.startsWith('/realtime/')) {
      return CommunicationTarget(
        owner: CommunicationOwner.standaloneRealtime,
        sessionId: sessionId.isEmpty ? null : sessionId,
        deeplink: deeplink.isEmpty ? null : deeplink,
        context: context.isEmpty ? 'STANDALONE' : context,
        mode: mode.isEmpty ? null : mode,
        attention: attention.isEmpty ? null : attention,
      );
    }

    return CommunicationTarget(
      owner: CommunicationOwner.unknown,
      sessionId: sessionId.isEmpty ? null : sessionId,
      deeplink: deeplink.isEmpty ? null : deeplink,
      context: context.isEmpty ? null : context,
      mode: mode.isEmpty ? null : mode,
      attention: attention.isEmpty ? null : attention,
    );
  }

  String resolveRoute(CommunicationTarget target) {
    switch (target.owner) {
      case CommunicationOwner.thread:
        if ((target.spaceId ?? '').isNotEmpty && (target.threadId ?? '').isNotEmpty) {
          return '/me/correspondence/${target.spaceId!}/thread/${target.threadId!}';
        }
        return target.deeplink ?? '/me/correspondence';
      case CommunicationOwner.space:
        if ((target.spaceId ?? '').isNotEmpty) {
          return '/me/correspondence/${target.spaceId!}';
        }
        return target.deeplink ?? '/me/correspondence';
      case CommunicationOwner.standaloneRealtime:
        if ((target.sessionId ?? '').isNotEmpty) {
          return '/realtime/${target.sessionId!}?action=join';
        }
        return target.deeplink ?? '/realtime';
      case CommunicationOwner.unknown:
        return target.deeplink ?? '/activity';
    }
  }

  _ResolvedDeeplink _parseDeeplink(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return const _ResolvedDeeplink();

    final threadMatch = RegExp(r'^/me/correspondence/([^/]+)/thread/([^/?#]+)').firstMatch(raw);
    if (threadMatch != null) {
      return _ResolvedDeeplink(
        ownerType: 'THREAD',
        spaceId: threadMatch.group(1),
        threadId: threadMatch.group(2),
      );
    }

    final spaceMatch = RegExp(r'^/me/correspondence/([^/?#]+)').firstMatch(raw);
    if (spaceMatch != null) {
      return _ResolvedDeeplink(ownerType: 'SPACE', spaceId: spaceMatch.group(1));
    }

    if (raw.startsWith('/realtime/')) {
      return const _ResolvedDeeplink(ownerType: 'REALTIME');
    }

    return const _ResolvedDeeplink();
  }
}

class _ResolvedDeeplink {
  final String? ownerType;
  final String? threadId;
  final String? spaceId;

  const _ResolvedDeeplink({this.ownerType, this.threadId, this.spaceId});
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
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
