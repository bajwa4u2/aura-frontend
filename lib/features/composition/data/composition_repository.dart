import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/composition_models.dart';

class CompositionRepository {
  final String baseUrl;
  final String token;

  CompositionRepository({
    required this.baseUrl,
    required this.token,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // REVIEW (light suggestions, no heavy mode)
  Future<CompositionReviewResult> review({
    required String text,
    required CompositionSurface surface,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/v1/composition/review'),
      headers: _headers,
      body: jsonEncode({
        'text': text,
        'surface': surface.name,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Review failed');
    }

    final data = jsonDecode(res.body);
    return CompositionReviewResult.fromJson(data);
  }

  // APPLY (already fixed contract)
  Future<String> apply({
    required String sessionId,
    required String suggestionId,
    required String currentText,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/v1/composition/apply'),
      headers: _headers,
      body: jsonEncode({
        'sessionId': sessionId,
        'findingId': suggestionId,
        'currentText': currentText,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Apply failed');
    }

    final data = jsonDecode(res.body);
    return data['text'] ?? currentText;
  }

  // TRANSLATION (new, clean)
  Future<CompositionTranslationResult> translate({
    required String text,
    required String targetLanguage,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/v1/composition/translate'),
      headers: _headers,
      body: jsonEncode({
        'text': text,
        'targetLanguage': targetLanguage,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Translation failed');
    }

    final data = jsonDecode(res.body);
    return CompositionTranslationResult.fromJson(data);
  }
}