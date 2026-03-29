import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

final invitationsClientProvider = Provider<InvitationsClient>((ref) {
  return InvitationsClient(ref.watch(dioProvider));
});

class InvitationsClient {
  InvitationsClient(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> loadInbox() async {
    final res = await _getFirstSuccessful([
      '/invites',
      '/v1/invites',
      '/invites/inbox',
      '/v1/invites/inbox',
    ]);
    return _extractInboxList(res.data);
  }

  Future<List<Map<String, dynamic>>> loadSent() async {
    final res = await _getFirstSuccessful([
      '/invites',
      '/v1/invites',
      '/invites/sent',
      '/v1/invites/sent',
    ]);
    return _extractScopedInviteList(
      res.data,
      preferredKeys: const ['sent'],
    );
  }

  Future<List<Map<String, dynamic>>> loadApprovals() async {
    final res = await _getFirstSuccessful([
      '/invites',
      '/v1/invites',
      '/invites/approvals',
      '/v1/invites/approvals',
    ]);
    return _extractScopedInviteList(
      res.data,
      preferredKeys: const ['approvals'],
    );
  }

  Future<Map<String, dynamic>> inspectToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) throw Exception('Missing invite token.');

    final attempts = <Future<Response<dynamic>> Function()>[
      () => _dio.get('/invite-links/$trimmed'),
      () => _dio.get('/v1/invite-links/$trimmed'),
      () => _dio.get('/invites/token/$trimmed'),
      () => _dio.get('/v1/invites/token/$trimmed'),
      () => _dio.get('/invites/inspect', queryParameters: {'token': trimmed}),
      () => _dio.get('/v1/invites/inspect', queryParameters: {'token': trimmed}),
    ];

    for (final attempt in attempts) {
      try {
        final res = await attempt();
        return _extractMap(res.data);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) continue;
        rethrow;
      }
    }

    throw Exception('Invite could not be found.');
  }

  Future<Map<String, dynamic>> createInvite({
    required String destinationType,
    String? accessPolicy,
    String? deliveryChannel,
    String? recipientType,
    String? message,
    String? recipientUserId,
    String? recipientHandle,
    String? spaceId,
    String? threadId,
    String? roleToGrant,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    final normalizedDestination = destinationType.trim().toUpperCase();
    final normalizedSpaceId = spaceId?.trim();
    final normalizedThreadId = threadId?.trim();
    final normalizedRecipientUserId = recipientUserId?.trim();
    final normalizedRecipientHandle = recipientHandle?.trim();
    final normalizedRole = _nonEmpty(roleToGrant) ? roleToGrant!.trim() : 'MEMBER';

    if (normalizedDestination == 'JOIN_SPACE' &&
        _nonEmpty(normalizedSpaceId) &&
        _nonEmpty(normalizedRecipientUserId)) {
      final res = await _postFirstSuccessful([
        '/spaces/$normalizedSpaceId/invites',
        '/v1/spaces/$normalizedSpaceId/invites',
      ], data: {
        'invitedUserId': normalizedRecipientUserId,
        'roleOffered': normalizedRole,
      });
      return _extractMap(res.data);
    }

    if (normalizedDestination == 'JOIN_THREAD' && _nonEmpty(normalizedThreadId)) {
      final res = await _postFirstSuccessful([
        '/threads/$normalizedThreadId/invites',
        '/v1/threads/$normalizedThreadId/invites',
      ], data: {
        'destinationType': normalizedDestination,
        if (_nonEmpty(accessPolicy)) 'accessPolicy': accessPolicy!.trim(),
        if (_nonEmpty(deliveryChannel)) 'deliveryChannel': deliveryChannel!.trim(),
        if (_nonEmpty(recipientType)) 'recipientType': recipientType!.trim(),
        if (_nonEmpty(message)) 'message': message!.trim(),
        if (_nonEmpty(normalizedRecipientUserId)) 'directRecipientId': normalizedRecipientUserId,
        if (_nonEmpty(normalizedRecipientHandle)) 'recipientHandle': normalizedRecipientHandle,
        if (_nonEmpty(roleToGrant)) 'roleToGrant': normalizedRole,
        if (maxUses != null) 'maxUses': maxUses,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      });
      return _extractMap(res.data);
    }

    final body = <String, dynamic>{
      'destinationType': normalizedDestination,
      if (_nonEmpty(accessPolicy)) 'accessPolicy': accessPolicy!.trim(),
      if (_nonEmpty(deliveryChannel)) 'deliveryChannel': deliveryChannel!.trim(),
      if (_nonEmpty(recipientType)) 'recipientType': recipientType!.trim(),
      if (_nonEmpty(message)) 'message': message!.trim(),
      if (_nonEmpty(normalizedRecipientUserId)) 'directRecipientId': normalizedRecipientUserId,
      if (_nonEmpty(normalizedRecipientHandle)) 'recipientHandle': normalizedRecipientHandle,
      if (_nonEmpty(roleToGrant)) 'roleToGrant': normalizedRole,
      if (maxUses != null) 'maxUses': maxUses,
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
    };

    final res = await _postFirstSuccessful([
      '/invites',
      '/v1/invites',
    ], data: body);
    return _extractMap(res.data);
  }

  Future<Map<String, dynamic>> respond({
    String? inviteId,
    String? token,
    required String action,
  }) async {
    final normalized = action.trim().toUpperCase();
    if (normalized.isEmpty) throw Exception('Missing invite action.');

    final attempts = <Future<Response<dynamic>> Function()>[];

    if (_nonEmpty(inviteId)) {
      final id = inviteId!.trim();
      attempts.add(() => _dio.post('/invites/$id/respond', data: {'action': normalized}));
      attempts.add(() => _dio.post('/v1/invites/$id/respond', data: {'action': normalized}));
      attempts.add(() => _dio.post('/invites/$id/${normalized.toLowerCase()}'));
      attempts.add(() => _dio.post('/v1/invites/$id/${normalized.toLowerCase()}'));
    }

    if (_nonEmpty(token)) {
      final t = token!.trim();
      attempts.add(() => _dio.post('/invite-links/$t/respond', data: {'action': normalized}));
      attempts.add(() => _dio.post('/v1/invite-links/$t/respond', data: {'action': normalized}));
      attempts.add(() => _dio.post('/invites/token/$t/respond', data: {'action': normalized}));
      attempts.add(() => _dio.post('/v1/invites/token/$t/respond', data: {'action': normalized}));
      attempts.add(() => _dio.post('/invites/respond', data: {'token': t, 'action': normalized}));
      attempts.add(() => _dio.post('/v1/invites/respond', data: {'token': t, 'action': normalized}));
    }

    for (final attempt in attempts) {
      try {
        final res = await attempt();
        return _extractMap(res.data);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) continue;
        rethrow;
      }
    }

    throw Exception('Invite response endpoint was not available.');
  }

  Future<Map<String, dynamic>> revokeInvite(String inviteId) async {
    final id = inviteId.trim();
    if (id.isEmpty) throw Exception('Missing invite id.');
    final res = await _postFirstSuccessful([
      '/invites/$id/revoke',
      '/v1/invites/$id/revoke',
    ]);
    return _extractMap(res.data);
  }

  Future<Response<dynamic>> _getFirstSuccessful(
    List<String> paths, {
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? last;
    for (final path in paths) {
      try {
        return await _dio.get(path, queryParameters: queryParameters);
      } on DioException catch (e) {
        last = e;
        if (e.response?.statusCode == 404) continue;
        rethrow;
      }
    }
    throw last ?? Exception('No endpoint available.');
  }

  Future<Response<dynamic>> _postFirstSuccessful(
    List<String> paths, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    DioException? last;
    for (final path in paths) {
      try {
        return await _dio.post(path, data: data, queryParameters: queryParameters);
      } on DioException catch (e) {
        last = e;
        if (e.response?.statusCode == 404) continue;
        rethrow;
      }
    }
    throw last ?? Exception('No endpoint available.');
  }
}

bool _nonEmpty(String? value) => value != null && value.trim().isNotEmpty;

Map<String, dynamic> _extractMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    const nestedKeys = ['data', 'invite', 'item', 'result', 'payload'];
    for (final key in nestedKeys) {
      final nested = raw[key];
      if (nested is Map<String, dynamic>) return _extractMap(nested);
      if (nested is Map) return _extractMap(Map<String, dynamic>.from(nested));
    }
    return raw;
  }
  if (raw is Map) return _extractMap(Map<String, dynamic>.from(raw));
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _extractInboxList(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];

    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);

      final received = _extractList(nested['received']);
      if (received.isNotEmpty) return received;

      final actionable = _extractList(nested['approvals']);
      if (actionable.isNotEmpty) return actionable;
    }
  }

  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);

    if (map.containsKey('received')) {
      final received = _extractList(map['received']);
      if (received.isNotEmpty) return received;
    }

    if (map.containsKey('approvals')) {
      final approvals = _extractList(map['approvals']);
      if (approvals.isNotEmpty) return approvals;
    }

    for (final key in const ['items', 'results', 'list', 'invites']) {
      final fallback = _extractList(map[key]);
      if (fallback.isNotEmpty) return fallback;
    }
  }

  return _extractList(raw);
}

List<Map<String, dynamic>> _extractScopedInviteList(
  dynamic raw, {
  required List<String> preferredKeys,
}) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);
      for (final key in preferredKeys) {
        final value = nested[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
        }
      }
    }

    for (final key in preferredKeys) {
      final value = map[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    }
  }
  return _extractList(raw);
}

List<Map<String, dynamic>> _extractList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    const keys = ['items', 'results', 'list', 'invites', 'data'];
    for (final key in keys) {
      final nested = map[key];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      if (nested is Map) {
        final list = _extractList(Map<String, dynamic>.from(nested));
        if (list.isNotEmpty) return list;
      }
    }
  }
  return const <Map<String, dynamic>>[];
}
