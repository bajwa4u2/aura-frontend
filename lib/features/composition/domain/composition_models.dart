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
    // The server's finding: `message`, an optional `suggestion` (advice), and
    // an optional `action` whose `preview` is the replacement text. Only a
    // finding with an action can be applied.
    final action = json['action'];
    final preview = action is Map ? (action['preview'] ?? '').toString() : '';
    final advice = (json['suggestion'] ?? '').toString().trim();
    final message = (json['message'] ?? '').toString().trim();
    return CompositionSuggestion(
      id: (json['id'] ?? '').toString(),
      message: advice.isEmpty ? message : '$message $advice',
      replacement: (json['replacement'] ?? preview).toString(),
      canApply: json['canApply'] as bool? ?? (action is Map),
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

  /// Reads the server's review: `{ok, data: {sessionId, findings}}` where
  /// `findings` groups items by chapter. This read a flat top-level list, so
  /// the panel never showed a finding (found 8 Oct 2026). Items the server
  /// marks OK are not suggestions and are left out.
  factory CompositionReviewResult.fromJson(Map<String, dynamic> json) {
    final inner = json['data'];
    final root = inner is Map && json['findings'] == null
        ? Map<String, dynamic>.from(inner)
        : json;
    final raw = root['findings'];
    final items = <Map<String, dynamic>>[];
    void take(dynamic list) {
      if (list is! List) return;
      for (final e in list) {
        if (e is Map) items.add(Map<String, dynamic>.from(e));
      }
    }

    if (raw is List) {
      take(raw);
    } else if (raw is Map) {
      for (final chapter in raw.values) {
        take(chapter);
      }
    }
    return CompositionReviewResult(
      sessionId: (root['sessionId'] ?? '').toString(),
      suggestions: items
          .where((e) => (e['state'] ?? '').toString().toUpperCase() != 'OK')
          .map(CompositionSuggestion.fromJson)
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