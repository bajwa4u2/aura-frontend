import 'package:dio/dio.dart';

import 'communication_translation.dart';

class CommunicationTranslationResult {
  const CommunicationTranslationResult({
    required this.translatedText,
    required this.targetLanguage,
    this.sourceLanguage,
    this.provider,
    this.cached = false,
  });

  final String translatedText;
  final String targetLanguage;
  final String? sourceLanguage;
  final String? provider;
  final bool cached;
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

String _readString(dynamic v) => (v ?? '').toString().trim();

/// Canonical client for `POST /communication/translate` — the single
/// governed translation capability shared by every publishable
/// communication surface (personal posts/replies/reshares, institution
/// posts/replies/reshares, announcements). No provider selection happens
/// here or at any call site; the backend's `CommunicationTranslationService`
/// owns fingerprinting, caching, and provider routing.
Future<CommunicationTranslationResult> translateCommunicationObject(
  Dio dio, {
  required CommunicationObjectType objectType,
  required String objectId,
  required String sourceText,
  String? sourceLanguage,
  required String targetLanguage,
}) async {
  final response = await dio.post(
    '/communication/translate',
    data: {
      'objectType': objectType.wireValue,
      'objectId': objectId,
      'sourceText': sourceText,
      if ((sourceLanguage ?? '').trim().isNotEmpty)
        'sourceLanguage': sourceLanguage!.trim(),
      'targetLanguage': targetLanguage,
    },
  );

  final root = _asMap(response.data);
  final data = _asMap(root['data']);
  final payload = data.isNotEmpty ? data : root;

  final translatedText = _readString(payload['translatedText']);
  if (translatedText.isEmpty) {
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Translation response was empty.',
    );
  }

  return CommunicationTranslationResult(
    translatedText: translatedText,
    targetLanguage: _readString(payload['targetLanguage']).isEmpty
        ? targetLanguage
        : _readString(payload['targetLanguage']),
    sourceLanguage: _readString(payload['sourceLanguage']).isEmpty
        ? null
        : _readString(payload['sourceLanguage']),
    provider: _readString(payload['provider']).isEmpty
        ? null
        : _readString(payload['provider']),
    cached: payload['cached'] == true,
  );
}
