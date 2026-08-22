import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'engagement_model.dart';

/// Canonical client for `/engagement/:targetType/:targetId`.
///
/// One repository for every eligible publication class. A surface passes its
/// [PublicationTarget]; nothing here knows or cares that articles exist.
class EngagementRepository {
  EngagementRepository(this._dio);
  final Dio _dio;

  String _base(PublicationTarget target, String id) =>
      '/engagement/${target.wireValue}/${Uri.encodeComponent(id)}';

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Map<AuraReaction, int> _breakdown(dynamic raw) {
    final out = <AuraReaction, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final r = AuraReaction.fromWire(k?.toString());
        final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
        if (r != null && n > 0) out[r] = n;
      });
    }
    return out;
  }

  Future<EngagementState> state(PublicationTarget target, String id) async {
    final res = await _dio.get<dynamic>(_base(target, id));
    final d = _unwrap(res.data);
    return EngagementState(
      myReaction: AuraReaction.fromWire(d['myReaction']?.toString()),
      count: (d['count'] as num?)?.toInt() ?? 0,
      breakdown: _breakdown(d['breakdown']),
      saved: d['saved'] == true,
    );
  }

  /// Toggles or replaces this actor's reaction. The server owns the rule —
  /// same type removes, different type replaces — so the client never tries to
  /// predict which happened and simply reports what came back.
  Future<EngagementState> react(
    PublicationTarget target,
    String id,
    AuraReaction reaction,
  ) async {
    final res = await _dio.post<dynamic>(
      '${_base(target, id)}/reactions',
      data: {'type': reaction.wireValue},
    );
    final d = _unwrap(res.data);
    final reacted = d['reacted'] == true;
    return EngagementState(
      myReaction: reacted ? AuraReaction.fromWire(d['type']?.toString()) : null,
      count: (d['count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> setSaved(
    PublicationTarget target,
    String id,
    bool saved,
  ) async {
    final path = '${_base(target, id)}/save';
    if (saved) {
      await _dio.put<dynamic>(path);
    } else {
      await _dio.delete<dynamic>(path);
    }
  }
}

final engagementRepositoryProvider = Provider<EngagementRepository>(
  (ref) => EngagementRepository(ref.watch(dioProvider)),
);

/// Engagement state for one publication. Keyed by class AND id, because ids
/// come from separate tables and two classes could in principle share one.
final engagementStateProvider = FutureProvider.autoDispose
    .family<EngagementState, ({PublicationTarget target, String id})>(
  (ref, key) =>
      ref.watch(engagementRepositoryProvider).state(key.target, key.id),
);
