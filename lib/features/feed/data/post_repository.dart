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
    await _dio.put(
      '/posts/draft',
      data: {
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
      },
    );
  }

  Future<void> publishDraft() async {
    await _dio.post('/posts/draft/publish');
  }

  Future<Map<String, dynamic>> presignMedia({
    required String fileName,
    required String mimeType,
    required int bytes,
    required String kind, // IMAGE | VIDEO
    int? width,
    int? height,
  }) async {
    final res = await _dio.post(
      '/media/presign',
      data: {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
        'kind': kind,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      },
    );

    return Map<String, dynamic>.from(res.data as Map);
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

  Future<void> markMediaReady(String mediaId) async {
    await _dio.post('/media/$mediaId/ready');
  }
}