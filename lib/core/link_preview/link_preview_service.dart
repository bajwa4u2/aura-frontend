import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'link_preview.dart';

final linkPreviewServiceProvider = Provider<LinkPreviewService>((ref) {
  return LinkPreviewService(ref.watch(dioProvider));
});

/// Compose Link Intelligence / OG Preview -- Phase 1.
///
/// Thin client for the canonical `POST /link-previews/resolve` endpoint.
/// The one place either composer calls to resolve a pasted URL -- no
/// duplicated OG-parsing logic on the client, since all parsing already
/// happened server-side.
class LinkPreviewService {
  LinkPreviewService(this._dio);

  final Dio _dio;

  Future<LinkPreview?> resolve(String url) async {
    try {
      final res = await _dio.post('/link-previews/resolve', data: {'url': url});
      final data = res.data;
      final map = data is Map
          ? (data['data'] is Map ? data['data'] : data)
          : null;
      if (map is! Map) return null;
      return LinkPreview.fromJson(Map<String, dynamic>.from(map));
    } on DioException {
      // Network/timeout/etc -- posting must still work with a plain URL,
      // so a resolve failure here is silent, not surfaced as a compose
      // error. The composer keeps whatever text the author typed either way.
      return null;
    }
  }
}
