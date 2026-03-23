import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/composition_models.dart';

final compositionRepositoryProvider = Provider<CompositionRepository>((ref) {
  return CompositionRepository(ref.read(dioProvider));
});

class CompositionRepository {
  CompositionRepository(this._dio);

  final Dio _dio;

  Future<CompositionReviewResult> review({
    required String text,
    required CompositionSurface surface,
  }) async {
    final response = await _dio.post(
      '/v1/composition/review',
      data: {
        'text': text,
        'surface': surface.apiValue,
      },
    );

    final root = _firstMap(response.data);
    return _parseReviewResult(root, fallbackSurface: surface);
  }

  Future<CompositionApplyResult> apply({
    required String sessionId,
    required String findingId,
    required String text,
    required CompositionSurface surface,
  }) async {
    final response = await _dio.post(
      '/v1/composition/apply',
      data: {
        'sessionId': sessionId,
        'findingId': findingId,
        'currentText': text,
      },
    );

    final root = _firstMap(response.data);
    final nextText = _firstNonEmptyString(root, const [
      ['text'],
      ['updatedText'],
      ['resultText'],
      ['revisedText'],
      ['content'],
      ['data', 'text'],
      ['data', 'updatedText'],
      ['result', 'text'],
      ['apply', 'text'],
      ['apply', 'updatedText'],
    ]);

    CompositionReviewResult? review;
    try {
      review = _parseReviewResult(root, fallbackSurface: surface);
    } catch (_) {
      review = null;
    }

    return CompositionApplyResult(
      text: nextText,
      review: review,
      raw: root,
    );
  }

  CompositionReviewResult _parseReviewResult(
    Map<String, dynamic> root, {
    required CompositionSurface fallbackSurface,
  }) {
    final sessionId = _findSessionId(root);
    final findings = _findFindings(root);
    final policy = _findPolicy(root);

    if (sessionId.isEmpty && findings.isEmpty) {
      throw Exception('Composition review response was missing session details.');
    }

    final surface = CompositionSurfaceX.tryParse(
          _firstNonEmptyString(root, const [
            ['surface'],
            ['context'],
            ['policy', 'surface'],
            ['review', 'surface'],
            ['data', 'surface'],
          ]),
        ) ??
        fallbackSurface;

    final allowApply = _firstBool(policy, const ['allowApply']) ??
        _firstBool(root, const ['allowApply']) ??
        false;

    final allowTranslation = _firstBool(policy, const ['allowTranslation']) ??
        _firstBool(root, const ['allowTranslation']) ??
        false;

    final intensity = _firstNonEmptyString(root, const [
      ['intensity'],
      ['policy', 'intensity'],
      ['review', 'intensity'],
      ['data', 'intensity'],
    ]);

    final summary = _firstNonEmptyString(root, const [
      ['summary'],
      ['message'],
      ['overview'],
      ['review', 'summary'],
      ['data', 'summary'],
    ]);

    return CompositionReviewResult(
      sessionId: sessionId,
      surface: surface,
      findings: findings,
      allowApply: allowApply,
      allowTranslation: allowTranslation,
      intensity: intensity,
      summary: summary,
      raw: root,
    );
  }

  Map<String, dynamic> _findPolicy(Map<String, dynamic> root) {
    for (final path in const [
      ['policy'],
      ['review', 'policy'],
      ['data', 'policy'],
      ['result', 'policy'],
    ]) {
      final value = _valueAtPath(root, path);
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _findSessionId(Map<String, dynamic> root) {
    return _firstNonEmptyString(root, const [
      ['sessionId'],
      ['session', 'id'],
      ['review', 'sessionId'],
      ['review', 'session', 'id'],
      ['data', 'sessionId'],
      ['data', 'session', 'id'],
      ['result', 'sessionId'],
      ['result', 'session', 'id'],
      ['id'],
    ]);
  }

  List<CompositionFinding> _findFindings(Map<String, dynamic> root) {
    for (final path in const [
      ['findings'],
      ['review', 'findings'],
      ['data', 'findings'],
      ['result', 'findings'],
      ['items'],
      ['data', 'items'],
    ]) {
      final value = _valueAtPath(root, path);

      if (value is List) {
        final parsed = _parseFindingList(value);
        if (parsed.isNotEmpty) return parsed;
      }

      if (value is Map) {
        final out = <CompositionFinding>[];

        value.forEach((chapterKey, listValue) {
          if (listValue is! List) return;

          final parsed = _parseFindingList(listValue).map((finding) {
            return CompositionFinding(
              id: finding.id,
              chapter: chapterKey.toString(),
              state: finding.state,
              message: finding.message,
              suggestion: finding.suggestion,
              actionType: finding.actionType,
              actionLabel: finding.actionLabel,
              raw: finding.raw,
            );
          });

          out.addAll(parsed);
        });

        if (out.isNotEmpty) return out;
      }
    }

    return const <CompositionFinding>[];
  }

  List<CompositionFinding> _parseFindingList(List<dynamic> list) {
    final out = <CompositionFinding>[];
    for (final item in list) {
      final map = _firstMap(item);
      if (map.isEmpty) continue;

      final id = _firstNonEmptyString(map, const [
        ['id'],
        ['findingId'],
        ['action', 'id'],
      ]);

      final chapter = _firstNonEmptyString(map, const [
        ['chapter'],
        ['group'],
        ['section'],
      ]);

      final state = _firstNonEmptyString(map, const [
        ['state'],
        ['status'],
        ['severity'],
      ]);

      final message = _firstNonEmptyString(map, const [
        ['message'],
        ['title'],
        ['finding'],
      ]);

      final suggestion = _firstNonEmptyString(map, const [
        ['suggestion'],
        ['detail'],
        ['description'],
        ['action', 'message'],
      ]);

      final actionType = _firstNonEmptyString(map, const [
        ['action', 'type'],
        ['actionType'],
      ]);

      final actionLabel = _firstNonEmptyString(map, const [
        ['action', 'label'],
        ['actionLabel'],
      ]);

      if (id.isEmpty && message.isEmpty && suggestion.isEmpty) {
        continue;
      }

      out.add(
        CompositionFinding(
          id: id.isEmpty ? '${out.length + 1}' : id,
          chapter: chapter.isEmpty ? 'General' : chapter,
          state: state.isEmpty ? 'OPEN' : state,
          message: message.isEmpty ? 'Suggested change' : message,
          suggestion: suggestion,
          actionType: actionType,
          actionLabel: actionLabel,
          raw: map,
        ),
      );
    }

    return out;
  }

  Map<String, dynamic> _firstMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  dynamic _valueAtPath(Map<String, dynamic> root, List<String> path) {
    dynamic current = root;
    for (final segment in path) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  String _firstNonEmptyString(
    Map<String, dynamic> root,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      final value = _valueAtPath(root, path);
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  bool? _firstBool(Map<String, dynamic> root, List<String> keys) {
    for (final key in keys) {
      final value = root[key];
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
    }
    return null;
  }
}