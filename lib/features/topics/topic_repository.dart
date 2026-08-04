import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'topic.dart';

/// One approved Secondary Topic for a given Primary, as read from the
/// backend's canonical relationship graph. `strength` is presentation
/// metadata only (not re-validated client-side) — the backend is the sole
/// authority for which relationships are approved at all.
class ApprovedSecondaryTopic {
  const ApprovedSecondaryTopic({required this.topic, required this.strength});

  final AuraTopic topic;
  final String strength;
}

/// Result of a ranked secondary-topic suggestion request. `mode` reflects
/// whether the backend served this from AI enrichment or its deterministic
/// keyword fallback — both are governed, gated results; this is informational
/// only.
class TopicSuggestionResult {
  const TopicSuggestionResult({required this.suggestions, required this.mode});

  final List<AuraTopic> suggestions;
  final String mode;
}

/// Read access to the backend's canonical Topic relationship graph and
/// suggestion capability. The client holds no copy of the relationship
/// graph itself (TOPIC_CLASSIFICATION_DOCTRINE.md: "the backend is the sole
/// authority for approved relationships") — every approved-set and
/// suggestion answer comes from here.
class TopicRepository {
  TopicRepository(this._dio);

  final Dio _dio;

  /// `GET /topics/:primary/secondaries` — the plain, deterministic approved
  /// set for [primary]. No AI, no text analysis; always available as long
  /// as the network call itself succeeds. Throws on failure — callers
  /// surface a recoverable error state rather than a local fallback.
  Future<List<ApprovedSecondaryTopic>> approvedSecondaries(
    AuraTopic primary,
  ) async {
    final res = await _dio.get('/topics/${primary.wire}/secondaries');
    return parseApprovedSecondaries(res.data);
  }

  /// `POST /topics/suggest-secondary` — ranked suggestions for [primary]
  /// given [text]. The backend applies the approved-relationship gate, then
  /// AI semantic relevance, then a deterministic keyword fallback if AI is
  /// unavailable — the caller never needs its own fallback logic. Throws on
  /// failure — callers surface a recoverable error state.
  Future<TopicSuggestionResult> suggestSecondary(
    AuraTopic primary,
    String text,
  ) async {
    final res = await _dio.post(
      '/topics/suggest-secondary',
      data: {'primaryTopic': primary.wire, 'text': text},
    );
    return parseSuggestionResult(res.data);
  }
}

/// Pure parsing of the `GET /topics/:primary/secondaries` response body —
/// extracted so it's unit-testable without mocking Dio's transport layer.
List<ApprovedSecondaryTopic> parseApprovedSecondaries(dynamic data) {
  final raw = data is Map ? data['approved'] : null;
  if (raw is! List) return const <ApprovedSecondaryTopic>[];
  final out = <ApprovedSecondaryTopic>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final topic = AuraTopic.fromWire(e['topic']?.toString());
    if (topic == null) continue;
    out.add(
      ApprovedSecondaryTopic(
        topic: topic,
        strength: e['strength']?.toString() ?? 'CONTEXTUAL',
      ),
    );
  }
  return out;
}

/// Pure parsing of the `POST /topics/suggest-secondary` response body —
/// extracted so it's unit-testable without mocking Dio's transport layer.
TopicSuggestionResult parseSuggestionResult(dynamic data) {
  final raw = data is Map ? data['suggestions'] : null;
  final mode = data is Map ? (data['mode']?.toString() ?? 'keyword') : 'keyword';
  final suggestions = <AuraTopic>[];
  if (raw is List) {
    for (final e in raw) {
      final topic = AuraTopic.fromWire((e is Map ? e['topic'] : null)?.toString());
      if (topic != null) suggestions.add(topic);
    }
  }
  return TopicSuggestionResult(suggestions: suggestions, mode: mode);
}

final topicRepositoryProvider = Provider<TopicRepository>((ref) {
  return TopicRepository(ref.watch(dioProvider));
});
