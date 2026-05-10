import 'package:dio/dio.dart';

import 'compatibility_models.dart';

/// Thin Dio wrapper around `GET /client/compatibility`. Slice C is read-only
/// from the client's perspective — the endpoint is idempotent and safe to
/// retry. The repository returns the typed model; mapping the response
/// envelope is the caller's job (envelope stripping happens here so the
/// provider stays UI-agnostic).
class CompatibilityRepository {
  CompatibilityRepository(this._dio);

  final Dio _dio;

  Future<CompatibilityVerdict> fetch() async {
    final response = await _dio.get<dynamic>(
      '/client/compatibility',
      options: Options(
        headers: const {'Accept': 'application/json'},
        // The endpoint is unauthenticated by design; do not attach a refresh
        // retry policy. A 401 here would be unexpected and should surface.
        validateStatus: (code) => code != null && code < 500,
      ),
    );

    final body = response.data;
    if (body is! Map) {
      return CompatibilityVerdict.compatible;
    }

    // The backend wraps every successful response in
    // ResponseWrapInterceptor's envelope. Slice B's controller returns the
    // verdict directly, which becomes `data` after wrapping. We tolerate
    // both shapes (wrapped + raw) so a future contract change does not
    // silently break the client.
    final dataField = body['data'];
    final verdictMap = dataField is Map<String, dynamic>
        ? dataField
        : (body is Map<String, dynamic> ? body : null);

    if (verdictMap == null) {
      return CompatibilityVerdict.compatible;
    }

    return CompatibilityVerdict.fromJson(verdictMap);
  }
}
