/// INSTITUTIONAL GRANT REQUESTS, AS AN OPERATOR SEES THEM.
///
/// An institution's owner may ask once for the 30-day Institutional Grant;
/// Aura decides. The backend has held these requests since monetization WP4
/// (`GET /monetization/admin/grant-requests`), and until this existed nothing
/// in the console could read or decide them: a request simply waited.
///
/// The work summary (`operator-work.service.ts`) does not enumerate this
/// source, so it is read here directly, the same way the institution
/// verification queue is.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

/// One request waiting for a decision.
class OperatorGrantRequest {
  const OperatorGrantRequest({
    required this.id,
    required this.institutionId,
    required this.institutionName,
    required this.requestedTier,
    this.institutionSlug,
    this.institutionPlan,
    this.requesterId,
    this.requesterName,
    this.requesterHandle,
    this.message,
    this.requestedAt,
    this.status = 'PENDING',
  });

  factory OperatorGrantRequest.fromJson(Map<String, dynamic> json) {
    final inst = _map(json['institution']);
    final by = _map(json['requestedBy']);
    return OperatorGrantRequest(
      id: (json['id'] ?? '').toString(),
      institutionId:
          (json['institutionId'] ?? inst?['id'] ?? '').toString(),
      institutionName: _text(inst?['name']) ?? 'An institution',
      institutionSlug: _text(inst?['slug']),
      institutionPlan: _text(inst?['plan']),
      requestedTier: (json['requestedTier'] ?? '').toString(),
      requesterId: _text(by?['id']),
      requesterName: _text(by?['displayName']),
      requesterHandle: _text(by?['handle']),
      message: _text(json['message']),
      requestedAt: json['requestedAt'] is String
          ? DateTime.tryParse(json['requestedAt'] as String)
          : null,
      status: (json['status'] ?? 'PENDING').toString(),
    );
  }

  final String id;
  final String institutionId;
  final String institutionName;
  final String? institutionSlug;

  /// The institution's plan now. A request from an institution that has
  /// since started paying cannot be approved; the server refuses it.
  final String? institutionPlan;
  final String requestedTier;
  final String? requesterId;
  final String? requesterName;
  final String? requesterHandle;
  final String? message;
  final DateTime? requestedAt;
  final String status;

  /// The person who asked, named as a person would name them.
  String get requesterLabel {
    final name = requesterName;
    final handle = requesterHandle;
    if (name != null && handle != null) return '$name · @$handle';
    if (name != null) return name;
    if (handle != null) return '@$handle';
    return 'Unknown person';
  }
}

class OperatorGrantRepository {
  OperatorGrantRepository(this._dio);

  final Dio _dio;

  Future<List<OperatorGrantRequest>> pending() async {
    final res = await _dio.get<dynamic>(
      '/monetization/admin/grant-requests',
      queryParameters: const {'status': 'PENDING'},
    );
    final data = _unwrap(res.data);
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map)
          OperatorGrantRequest.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> approve(String grantId) async {
    await _dio.post<dynamic>(
      '/monetization/admin/grant-requests/${Uri.encodeComponent(grantId)}/approve',
    );
  }

  Future<void> decline(String grantId, {String? reason}) async {
    await _dio.post<dynamic>(
      '/monetization/admin/grant-requests/${Uri.encodeComponent(grantId)}/decline',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  // Successful responses arrive as `{ok: true, data: <payload>}`.
  static dynamic _unwrap(dynamic raw) {
    if (raw is Map && raw.containsKey('data')) return raw['data'];
    return raw;
  }
}

final operatorGrantRepositoryProvider = Provider<OperatorGrantRepository>(
  (ref) => OperatorGrantRepository(ref.watch(dioProvider)),
);

/// Requests waiting for a decision, oldest first (the server's order).
final pendingGrantRequestsProvider =
    FutureProvider.autoDispose<List<OperatorGrantRequest>>(
      (ref) => ref.watch(operatorGrantRepositoryProvider).pending(),
    );

Map<String, dynamic>? _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}
