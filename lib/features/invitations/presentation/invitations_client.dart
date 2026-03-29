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
    return _extractList(res.data);
  }

  Future<List<Map<String, dynamic>>> loadSent() async {
    final res = await _getFirstSuccessful([
      '/invites',
      '/v1/invites',
    ], queryParameters: const {'scope': 'sent'});
    return _extractList(res.data);
  }

  Future<List<Map<String, dynamic>>> loadApprovals() async {
    final res = await _getFirstSuccessful([
      '/invites',
      '/v1/invites',
    ]);

    final root = _extractMap(res.data);
    final approvals = root['approvals'];
    if (approvals is List) {
      return approvals
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
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
    String? recipientEmail,
    String? recipientName,
    String? recipientPhone,
    String? sourcePlatform,
    String? spaceId,
    String? threadId,
    String? roleToGrant,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    final normalizedDestination = destinationType.trim().toUpperCase();

    if (normalizedDestination == 'JOIN_SPACE') {
      final space = spaceId?.trim() ?? '';
      final userId = recipientUserId?.trim() ?? '';
      if (space.isEmpty) {
        throw Exception('Missing space id for space invitation.');
      }
      if (userId.isEmpty) {
        throw Exception('Missing recipient user id for space invitation.');
      }

      final res = await _postFirstSuccessful([
        '/spaces/$space/invites',
        '/v1/spaces/$space/invites',
      ], data: {
        'invitedUserId': userId,
        'roleOffered': _normalizeRoleOffered(roleToGrant),
      });
      return _extractMap(res.data);
    }

    if (normalizedDestination == 'JOIN_THREAD' || normalizedDestination == 'START_1_TO_1') {
      final thread = threadId?.trim() ?? '';
      if (thread.isEmpty) {
        throw Exception('Missing thread id for thread invitation.');
      }

      final body = <String, dynamic>{
        'destinationType': normalizedDestination,
        if (_nonEmpty(accessPolicy)) 'accessPolicy': accessPolicy!.trim(),
        if (_nonEmpty(deliveryChannel)) 'deliveryChannel': deliveryChannel!.trim(),
        if (_nonEmpty(recipientType)) 'recipientType': recipientType!.trim(),
        if (_nonEmpty(message)) 'message': message!.trim(),
        if (_nonEmpty(recipientUserId)) 'directRecipientId': recipientUserId!.trim(),
        if (_nonEmpty(recipientHandle)) 'recipientHandle': recipientHandle!.trim(),
        if (_nonEmpty(recipientEmail)) 'recipientEmail': recipientEmail!.trim(),
        if (_nonEmpty(recipientName)) 'recipientName': recipientName!.trim(),
        if (_nonEmpty(recipientPhone)) 'recipientPhone': recipientPhone!.trim(),
        if (_nonEmpty(sourcePlatform)) 'sourcePlatform': sourcePlatform!.trim(),
        if (_nonEmpty(roleToGrant)) 'roleToGrant': roleToGrant!.trim(),
        if (maxUses != null) 'maxUses': maxUses,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

      final res = await _postFirstSuccessful([
        '/threads/$thread/invites',
        '/v1/threads/$thread/invites',
      ], data: body);
      return _extractMap(res.data);
    }

    final body = <String, dynamic>{
      'destinationType': 'JOIN_AURA',
      if (_nonEmpty(accessPolicy)) 'accessPolicy': accessPolicy!.trim(),
      if (_nonEmpty(deliveryChannel)) 'deliveryChannel': deliveryChannel!.trim(),
      if (_nonEmpty(recipientType)) 'recipientType': recipientType!.trim(),
      if (_nonEmpty(message)) 'message': message!.trim(),
      if (_nonEmpty(recipientUserId)) 'directRecipientId': recipientUserId!.trim(),
      if (_nonEmpty(recipientHandle)) 'recipientHandle': recipientHandle!.trim(),
      if (_nonEmpty(recipientEmail)) 'recipientEmail': recipientEmail!.trim(),
      if (_nonEmpty(recipientName)) 'recipientName': recipientName!.trim(),
      if (_nonEmpty(recipientPhone)) 'recipientPhone': recipientPhone!.trim(),
      if (_nonEmpty(sourcePlatform)) 'sourcePlatform': sourcePlatform!.trim(),
      if (_nonEmpty(roleToGrant)) 'roleToGrant': roleToGrant!.trim(),
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

String _normalizeRoleOffered(String? roleToGrant) {
  final role = roleToGrant?.trim().toUpperCase();
  switch (role) {
    case 'OWNER':
    case 'ADMIN':
    case 'EDITOR':
    case 'CONTRIBUTOR':
    case 'MEMBER':
    case 'VIEWER':
      return role!;
    default:
      return 'MEMBER';
  }
}

Map<String, dynamic> _extractMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    const nestedKeys = [
      'data',
      'invite',
      'invitation',
      'item',
      'result',
      'payload',
    ];
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

List<Map<String, dynamic>> _extractList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    const keys = ['items', 'results', 'list', 'invites', 'data', 'sent', 'received'];
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
