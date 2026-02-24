import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

class PostsRepository {
  PostsRepository(this._dio);

  final Dio _dio;

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
    // Use the same Dio instance; absolute URL is fine.
    await _dio.put(
      url,
      data: bytes,
      options: Options(
        headers: headers.map((k, v) => MapEntry(k.toString(), v.toString())),
        contentType: mimeType,
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );
  }

  Future<Map<String, dynamic>> fetchLinkPreview({required String url}) async {
    final res = await _dio.post(
      '/media/link-preview',
      data: {'url': url},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> markMediaReady(String mediaId) async {
    await _dio.post('/media/$mediaId/ready');
  }
}

/// Canonical provider name (plural matches class name).
final postsRepositoryProvider = Provider<PostsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PostsRepository(dio);
});

/// Backward-compatible alias (your compose screen expects this name).
final postRepositoryProvider = postsRepositoryProvider;