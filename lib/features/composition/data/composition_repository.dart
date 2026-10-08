import 'package:dio/dio.dart';

import '../domain/composition_models.dart';

/// Writing assistance for hosts that do not use [CompositionAssist].
///
/// Goes through the app's shared [Dio] (its base URL owns `/v1`, and it
/// refreshes the session). This used to post with `package:http` to
/// `$apiBaseUrl/v1/composition/...`; the base URL already ends in `/v1`, so
/// every review, apply and translation from the announcement editor went to
/// `/v1/v1/...` and failed (2026-10-08).
class CompositionRepository {
  CompositionRepository(this._dio, {this.actingForInstitutionId});

  final Dio _dio;

  /// Set when writing FOR an institution: the work is counted against its
  /// allowance, as in [CompositionAssist].
  final String? actingForInstitutionId;

  Map<String, dynamic> get _actingFor {
    final id = actingForInstitutionId?.trim() ?? '';
    return id.isEmpty ? const {} : {'actingForInstitutionId': id};
  }

  Future<CompositionReviewResult> review({
    required String text,
    required CompositionSurface surface,
  }) async {
    final res = await _dio.post(
      '/composition/review',
      data: {'text': text, 'surface': surface.name, ..._actingFor},
    );
    return CompositionReviewResult.fromJson(_asMap(res.data));
  }

  Future<String> apply({
    required String sessionId,
    required String suggestionId,
    required String currentText,
  }) async {
    final res = await _dio.post(
      '/composition/apply',
      data: {
        'sessionId': sessionId,
        'findingId': suggestionId,
        'currentText': currentText,
      },
    );
    final root = _asMap(res.data);
    return _firstNonEmpty([
      _str(root['text']),
      _str(root['updatedText']),
      _str(_asMap(root['data'])['text']),
      _str(_asMap(root['data'])['updatedText']),
    ], fallback: currentText);
  }

  Future<CompositionTranslationResult> translate({
    required String text,
    required String targetLanguage,
  }) async {
    final res = await _dio.post(
      '/composition/translate',
      data: {'text': text, 'targetLanguage': targetLanguage, ..._actingFor},
    );
    final root = _asMap(res.data);
    final translated = _firstNonEmpty([
      _str(root['translatedText']),
      _str(root['text']),
      _str(_asMap(root['data'])['translatedText']),
      _str(_asMap(root['data'])['text']),
    ]);
    if (translated.isEmpty) throw Exception('Translation was empty.');
    return CompositionTranslationResult(
      translatedText: translated,
      targetLanguage: targetLanguage,
    );
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();

  static String _firstNonEmpty(List<String?> values, {String fallback = ''}) {
    for (final v in values) {
      final s = (v ?? '').trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }
}
