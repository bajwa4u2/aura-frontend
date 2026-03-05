import 'dart:typed_data';

import 'package:dio/dio.dart';

class PostsRepository {
  PostsRepository(this._dio);

  final Dio _dio;

  // A clean client for presigned uploads (no auth interceptors).
  Dio _uploadDio() {
    return Dio(
      BaseOptions(
        // don't inherit baseUrl / interceptors from API client
        responseType: ResponseType.plain,
        followRedirects: true,
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrap(dynamic body) {
    final root = _asMap(body);
    if (root.containsKey('ok') && root.containsKey('data')) {
      return _asMap(root['data']);
    }
    return root;
  }

  bool _isNotFound(DioException e) => e.response?.statusCode == 404;

  Future<Response<dynamic>> _postWithFallback(
    String primaryPath,
    String fallbackPath, {
    Object? data,
  }) async {
    try {
      return await _dio.post(primaryPath, data: data);
    } on DioException catch (e) {
      if (_isNotFound(e)) {
        return await _dio.post(fallbackPath, data: data);
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> _putWithFallback(
    String primaryPath,
    String fallbackPath, {
    Object? data,
  }) async {
    try {
      return await _dio.put(primaryPath, data: data);
    } on DioException catch (e) {
      if (_isNotFound(e)) {
        return await _dio.put(fallbackPath, data: data);
      }
      rethrow;
    }
  }

  Future<void> saveDraft({
    required String text,
    String? mediaType,
    String? mediaUrl,
    String? mediaThumbUrl,
    int? mediaWidth,
    int? mediaHeight,
    int? mediaDuration,
    String? caption,
    String? linkTitle,
    String? linkDescription,
    String? linkImageUrl,
  }) async {
    // Backend currently accepts only text, but we keep the full payload for forward compatibility.
    final payload = <String, dynamic>{
      'text': text,
      if (mediaType != null) 'mediaType': mediaType,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaThumbUrl != null) 'mediaThumbUrl': mediaThumbUrl,
      if (mediaWidth != null) 'mediaWidth': mediaWidth,
      if (mediaHeight != null) 'mediaHeight': mediaHeight,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
      if (caption != null) 'caption': caption,
      if (linkTitle != null) 'linkTitle': linkTitle,
      if (linkDescription != null) 'linkDescription': linkDescription,
      if (linkImageUrl != null) 'linkImageUrl': linkImageUrl,
    };

    // Prefer /posts/draft (current controller). If some env still uses /posts/drafts, fallback.
    await _putWithFallback('/posts/draft', '/posts/drafts', data: payload);
  }

  Future<void> publishDraft() async {
    // Prefer the stable controller route we locked: /posts/draft/publish
    await _postWithFallback('/posts/draft/publish', '/posts/drafts/publish');
  }

  /// Presign upload. We tolerate both:
  /// - POST /media/presign  (older)
  /// - POST /uploads/presign (newer)
  ///
  /// Expected payload (typical):
  /// { id, url, headers, publicUrl?, thumbUrl? ... }
  Future<Map<String, dynamic>> presignMedia({
    required String fileName,
    required String mimeType,
    required int bytes,
    required String kind, // IMAGE | VIDEO
    int? width,
    int? height,
  }) async {
    final payload = <String, dynamic>{
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': bytes,
      'kind': kind,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    };

    final res = await _postWithFallback('/media/presign', '/uploads/presign', data: payload);

    final m = _unwrap(res.data);
    return m;
  }

  Future<void> uploadToPresignedUrl({
    required String url,
    required Map<String, dynamic> headers,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final dio = _uploadDio();

    // Presigned PUT: send only what backend told us to send.
    final uploadHeaders = <String, String>{};
    headers.forEach((k, v) {
      if (v == null) return;
      uploadHeaders[k.toString()] = v.toString();
    });

    // Ensure Content-Type matches what was signed.
    if (!uploadHeaders.containsKey('Content-Type')) {
      uploadHeaders['Content-Type'] = mimeType;
    }

    await dio.put(
      url,
      data: bytes,
      options: Options(
        headers: uploadHeaders,
        contentType: uploadHeaders['Content-Type'],
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );
  }

  /// Mark uploaded media as READY.
  /// Tolerate both:
  /// - POST /media/:id/ready
  /// - POST /uploads/:id/ready
  Future<void> markMediaReady(String mediaId) async {
    final id = mediaId.trim();
    if (id.isEmpty) return;

    await _postWithFallback('/media/$id/ready', '/uploads/$id/ready');
  }
}