import 'dart:typed_data';

import 'package:dio/dio.dart';

class PostsRepository {
  PostsRepository(this._dio);

  final Dio _dio;

  Dio _uploadDio() {
    return Dio(
      BaseOptions(
        responseType: ResponseType.plain,
        followRedirects: true,
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrapMap(dynamic body) {
    final root = _asMap(body);
    final data = root['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return root;
  }

  List<dynamic> _unwrapList(dynamic body) {
    if (body is List) return body;

    final root = _asMap(body);
    final data = root['data'];

    if (data is List) return data;
    if (root['items'] is List) return root['items'] as List<dynamic>;
    if (root['results'] is List) return root['results'] as List<dynamic>;

    if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
      if (inner['items'] is List) return inner['items'] as List<dynamic>;
      if (inner['results'] is List) return inner['results'] as List<dynamic>;
    }

    return const <dynamic>[];
  }

  bool _isNotFound(DioException e) => e.response?.statusCode == 404;

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  Future<Response<dynamic>> _postWithFallback(
    String primaryPath,
    String fallbackPath, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(
        primaryPath,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      if (_isNotFound(e)) {
        return await _dio.post(
          fallbackPath,
          data: data,
          queryParameters: queryParameters,
        );
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

  Future<Response<dynamic>> _getWithFallback(
    String primaryPath,
    String fallbackPath, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(primaryPath, queryParameters: queryParameters);
    } on DioException catch (e) {
      if (_isNotFound(e)) {
        return await _dio.get(fallbackPath, queryParameters: queryParameters);
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
    String? sourceLanguage,
    Map<String, dynamic>? translation,
    Map<String, dynamic>? composition,
  }) async {
    final payload = <String, dynamic>{
      'text': text,
      if (_hasText(mediaType)) 'mediaType': mediaType,
      if (_hasText(mediaUrl)) 'mediaUrl': mediaUrl,
      if (_hasText(mediaThumbUrl)) 'mediaThumbUrl': mediaThumbUrl,
      if (mediaWidth != null) 'mediaWidth': mediaWidth,
      if (mediaHeight != null) 'mediaHeight': mediaHeight,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
      if (_hasText(caption)) 'caption': caption,
      if (_hasText(linkTitle)) 'linkTitle': linkTitle,
      if (_hasText(linkDescription)) 'linkDescription': linkDescription,
      if (_hasText(linkImageUrl)) 'linkImageUrl': linkImageUrl,
      if (_hasText(sourceLanguage)) 'sourceLanguage': sourceLanguage,
      if (translation != null && translation.isNotEmpty) 'translation': translation,
      if (composition != null && composition.isNotEmpty) 'composition': composition,
    };

    await _putWithFallback('/posts/draft', '/posts/drafts', data: payload);
  }

  Future<void> publishDraft({
    String? sourceLanguage,
    Map<String, dynamic>? translation,
    Map<String, dynamic>? composition,
  }) async {
    final payload = <String, dynamic>{
      if (_hasText(sourceLanguage)) 'sourceLanguage': sourceLanguage,
      if (translation != null && translation.isNotEmpty) 'translation': translation,
      if (composition != null && composition.isNotEmpty) 'composition': composition,
    };

    await _postWithFallback(
      '/posts/draft/publish',
      '/posts/drafts/publish',
      data: payload.isEmpty ? null : payload,
    );
  }

  Future<Map<String, dynamic>> getDraft() async {
    final res = await _getWithFallback('/posts/draft', '/posts/drafts');
    return _unwrapMap(res.data);
  }

  Future<Map<String, dynamic>> previewDraftTranslation({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final payload = <String, dynamic>{
      'text': text.trim(),
      'targetLanguage': targetLanguage.trim(),
      if (_hasText(sourceLanguage)) 'sourceLanguage': sourceLanguage!.trim(),
    };

    final res = await _dio.post(
      '/composition/translate',
      data: payload,
    );

    final map = _unwrapMap(res.data);
    final translatedText = _pickString(
      map,
      const ['translatedText', 'text', 'translation', 'translated_text'],
    );

    return <String, dynamic>{
      'translatedText': translatedText,
      'targetLanguage': _pickString(
        map,
        const ['targetLanguage', 'language', 'target_language'],
      ).isEmpty
          ? targetLanguage.trim()
          : _pickString(
              map,
              const ['targetLanguage', 'language', 'target_language'],
            ),
      'sourceLanguage': _pickString(
        map,
        const ['sourceLanguage', 'source_language'],
      ).isEmpty
          ? (sourceLanguage ?? '')
          : _pickString(map, const ['sourceLanguage', 'source_language']),
      'raw': map,
    };
  }

  Future<Map<String, dynamic>> fetchPostTranslation({
    required String postId,
    required String targetLanguage,
  }) async {
    final pid = postId.trim();
    if (pid.isEmpty) {
      return <String, dynamic>{
        'postId': '',
        'translatedText': '',
        'targetLanguage': targetLanguage.trim(),
        'sourceLanguage': '',
        'raw': const <String, dynamic>{},
      };
    }

    try {
      final res = await _getWithFallback(
        '/posts/$pid/translation',
        '/posts/$pid/translate',
        queryParameters: {
          'targetLanguage': targetLanguage.trim(),
        },
      );

      final map = _unwrapMap(res.data);
      return <String, dynamic>{
        'postId': pid,
        'translatedText': _pickString(
          map,
          const ['translatedText', 'text', 'translation', 'translated_text'],
        ),
        'targetLanguage': _pickString(
          map,
          const ['targetLanguage', 'language', 'target_language'],
        ).isEmpty
            ? targetLanguage.trim()
            : _pickString(
                map,
                const ['targetLanguage', 'language', 'target_language'],
              ),
        'sourceLanguage': _pickString(
          map,
          const ['sourceLanguage', 'source_language'],
        ),
        'raw': map,
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final payload = <String, dynamic>{
          'targetLanguage': targetLanguage.trim(),
        };

        final res = await _postWithFallback(
          '/posts/$pid/translation',
          '/posts/$pid/translate',
          data: payload,
        );

        final map = _unwrapMap(res.data);
        return <String, dynamic>{
          'postId': pid,
          'translatedText': _pickString(
            map,
            const ['translatedText', 'text', 'translation', 'translated_text'],
          ),
          'targetLanguage': _pickString(
            map,
            const ['targetLanguage', 'language', 'target_language'],
          ).isEmpty
              ? targetLanguage.trim()
              : _pickString(
                  map,
                  const ['targetLanguage', 'language', 'target_language'],
                ),
          'sourceLanguage': _pickString(
            map,
            const ['sourceLanguage', 'source_language'],
          ),
          'raw': map,
        };
      }
      rethrow;
    }
  }

  Future<List<String>> fetchAvailableTranslationLanguages(String postId) async {
    final pid = postId.trim();
    if (pid.isEmpty) return const <String>[];

    try {
      final res = await _getWithFallback(
        '/posts/$pid/translations',
        '/posts/$pid/languages',
      );

      final list = _unwrapList(res.data);
      return list
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const <String>[];
      rethrow;
    }
  }

  Future<Map<String, dynamic>> presignMedia({
    required String fileName,
    required String mimeType,
    required int bytes,
    required String kind,
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

    final res = await _dio.post(
      '/media/presign',
      data: payload,
    );

    return _unwrapMap(res.data);
  }

  Future<void> uploadToPresignedUrl({
    required String url,
    required Map<String, dynamic> headers,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final dio = _uploadDio();

    final uploadHeaders = <String, String>{};
    headers.forEach((key, value) {
      if (value == null) return;
      uploadHeaders[key.toString()] = value.toString();
    });

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

}
