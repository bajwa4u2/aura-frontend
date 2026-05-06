import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';

/// Result of a single translation call. `fallback` is true when the
/// backend could not actually translate (no provider configured or all
/// providers failed) and returned the original source text.
class TranslationResult {
  TranslationResult({
    required this.translatedText,
    required this.targetLanguage,
    required this.sourceLanguage,
    required this.provider,
    required this.fallback,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      translatedText: (json['translatedText'] ?? '').toString(),
      targetLanguage: (json['targetLanguage'] ?? '').toString(),
      sourceLanguage: json['sourceLanguage']?.toString(),
      provider: (json['provider'] ?? '').toString(),
      fallback: json['fallback'] == true,
    );
  }

  final String translatedText;
  final String targetLanguage;
  final String? sourceLanguage;
  final String provider;

  /// True when the backend returned the source text unchanged. The UI
  /// MUST surface a clear "translation unavailable" hint instead of
  /// silently rendering the original.
  final bool fallback;
}

final translationRepositoryProvider =
    Provider<TranslationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TranslationRepository(dio);
});

class TranslationRepository {
  TranslationRepository(this._dio);
  final dynamic _dio;

  /// POST /v1/composition/translate. Goes through Dio so auth + cookies
  /// + the standard error envelope are all handled the same way as the
  /// rest of the app.
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final res = await _dio.post(
      '/composition/translate',
      data: {
        'text': text,
        'targetLanguage': targetLanguage,
        if (sourceLanguage != null && sourceLanguage.trim().isNotEmpty)
          'sourceLanguage': sourceLanguage,
      },
    );

    final raw = res.data;
    Map<String, dynamic> payload = const <String, dynamic>{};
    if (raw is Map) {
      final data = raw['data'];
      if (data is Map) {
        payload = Map<String, dynamic>.from(data);
      } else {
        payload = Map<String, dynamic>.from(raw);
      }
    }

    return TranslationResult.fromJson(payload);
  }
}
