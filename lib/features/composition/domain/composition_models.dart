enum CompositionSurface {
  post,
  message,
  announcement,
  space,
}

class CompositionSuggestion {
  final String id;
  final String message;
  final String replacement;
  final bool canApply;

  CompositionSuggestion({
    required this.id,
    required this.message,
    required this.replacement,
    this.canApply = true,
  });

  factory CompositionSuggestion.fromJson(Map<String, dynamic> json) {
    return CompositionSuggestion(
      id: json['id'] ?? '',
      message: json['message'] ?? '',
      replacement: json['replacement'] ?? '',
      canApply: json['canApply'] ?? true,
    );
  }
}

class CompositionReviewResult {
  final String sessionId;
  final List<CompositionSuggestion> suggestions;

  CompositionReviewResult({
    required this.sessionId,
    required this.suggestions,
  });

  factory CompositionReviewResult.fromJson(Map<String, dynamic> json) {
    final findings = json['findings'] as List? ?? [];

    return CompositionReviewResult(
      sessionId: json['sessionId'] ?? '',
      suggestions: findings
          .map((e) => CompositionSuggestion.fromJson(e))
          .toList(),
    );
  }
}

class CompositionTranslationResult {
  final String translatedText;
  final String targetLanguage;

  CompositionTranslationResult({
    required this.translatedText,
    required this.targetLanguage,
  });

  factory CompositionTranslationResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return CompositionTranslationResult(
      translatedText: json['translatedText'] ?? '',
      targetLanguage: json['targetLanguage'] ?? '',
    );
  }
}