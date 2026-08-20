import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import 'media_restriction.dart';

/// CH-12 — the client half of the governed route back.
///
/// Thin on purpose. Standing, eligibility, notice wording and lifecycle all
/// live on the server; this carries requests there and parses what comes back.
/// Duplicating any of that judgement here would create a second answer to an
/// authorization question, and the two would eventually disagree.
///
/// Authentication rides on the app's normal authenticated Dio client. No token
/// is read, held or attached by hand anywhere in this feature.
class MediaGovernanceRepository {
  MediaGovernanceRepository(this._dio);

  final Dio _dio;

  /// What the server says about this object for THIS caller.
  Future<MediaRestriction> fetchRestriction(String mediaId) async {
    final res = await _dio.get<dynamic>('/v1/media/$mediaId/restriction');
    return MediaRestriction.fromJson(_unwrap(res.data));
  }

  /// Submit an appeal. Throws on refusal so the surface can show the server's
  /// own reason rather than inventing one.
  Future<MediaAppeal> submitAppeal(String mediaId, String statement) async {
    final res = await _dio.post<dynamic>(
      '/v1/media/$mediaId/appeal',
      data: <String, dynamic>{'statement': statement},
    );
    return MediaAppeal.fromJson(_unwrap(res.data));
  }

  /// The caller's own view of their appeal, when one exists.
  Future<MediaAppeal?> fetchAppeal(String mediaId) async {
    final res = await _dio.get<dynamic>('/v1/media/$mediaId/appeal');
    final data = _unwrapOrNull(res.data);
    return data == null ? null : MediaAppeal.fromJson(data);
  }

  Map<String, dynamic> _unwrap(dynamic body) {
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final data = map['data'];
    return data is Map ? Map<String, dynamic>.from(data) : map;
  }

  Map<String, dynamic>? _unwrapOrNull(dynamic body) {
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final data = map['data'];
    if (data == null) return null;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }
}

final mediaGovernanceRepositoryProvider = Provider<MediaGovernanceRepository>(
  (ref) => MediaGovernanceRepository(ref.read(dioProvider)),
);

/// The restriction for one object.
///
/// Autodisposing and re-fetched on invalidation rather than cached long: a
/// restriction can be lifted at any moment by a reviewer, and a member staring
/// at a stale "restricted" banner after their appeal succeeded is the exact
/// failure the lifted notice exists to prevent.
final mediaRestrictionProvider =
    FutureProvider.autoDispose.family<MediaRestriction, String>((ref, mediaId) {
  return ref.read(mediaGovernanceRepositoryProvider).fetchRestriction(mediaId);
});
