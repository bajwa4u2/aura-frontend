import 'package:flutter/foundation.dart';

enum CompositionSurface {
  composer,
  space,
  dm,
}

extension CompositionSurfaceX on CompositionSurface {
  String get apiValue {
    switch (this) {
      case CompositionSurface.composer:
        return 'COMPOSER';
      case CompositionSurface.space:
        return 'SPACE';
      case CompositionSurface.dm:
        return 'DM';
    }
  }

  String get label {
    switch (this) {
      case CompositionSurface.composer:
        return 'Composer';
      case CompositionSurface.space:
        return 'Space';
      case CompositionSurface.dm:
        return 'Direct message';
    }
  }

  static CompositionSurface? tryParse(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    switch (value) {
      case 'COMPOSER':
      case 'COMPOSE':
      case 'POST':
        return CompositionSurface.composer;
      case 'SPACE':
      case 'SPACES':
        return CompositionSurface.space;
      case 'DM':
      case 'DIRECT':
      case 'DIRECT_MESSAGE':
      case 'REPLY':
        return CompositionSurface.dm;
      default:
        return null;
    }
  }
}

@immutable
class CompositionFinding {
  const CompositionFinding({
    required this.id,
    required this.chapter,
    required this.state,
    required this.message,
    required this.suggestion,
    required this.actionType,
    required this.actionLabel,
    required this.raw,
  });

  final String id;
  final String chapter;
  final String state;
  final String message;
  final String suggestion;
  final String actionType;
  final String actionLabel;
  final Map<String, dynamic> raw;

  String get chapterLabel {
    final value = chapter.trim();
    if (value.isEmpty) return 'General';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  String get stateLabel {
    final value = state.trim();
    if (value.isEmpty) return 'Open';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  bool get isResolved {
    final value = state.trim().toUpperCase();
    return value == 'OK' || value == 'RESOLVED' || value == 'PASS';
  }

  bool get isWarning {
    final value = state.trim().toUpperCase();
    return value == 'WARN' || value == 'WARNING' || value == 'NEEDS_ATTENTION';
  }
}

@immutable
class CompositionReviewResult {
  const CompositionReviewResult({
    required this.sessionId,
    required this.surface,
    required this.findings,
    required this.allowApply,
    required this.allowTranslation,
    required this.intensity,
    required this.summary,
    required this.raw,
  });

  final String sessionId;
  final CompositionSurface surface;
  final List<CompositionFinding> findings;
  final bool allowApply;
  final bool allowTranslation;
  final String intensity;
  final String summary;
  final Map<String, dynamic> raw;

  String get intensityLabel {
    final value = intensity.trim();
    if (value.isEmpty) return '';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  CompositionReviewResult copyWith({
    String? sessionId,
    CompositionSurface? surface,
    List<CompositionFinding>? findings,
    bool? allowApply,
    bool? allowTranslation,
    String? intensity,
    String? summary,
    Map<String, dynamic>? raw,
  }) {
    return CompositionReviewResult(
      sessionId: sessionId ?? this.sessionId,
      surface: surface ?? this.surface,
      findings: findings ?? this.findings,
      allowApply: allowApply ?? this.allowApply,
      allowTranslation: allowTranslation ?? this.allowTranslation,
      intensity: intensity ?? this.intensity,
      summary: summary ?? this.summary,
      raw: raw ?? this.raw,
    );
  }
}

@immutable
class CompositionApplyResult {
  const CompositionApplyResult({
    required this.text,
    this.review,
    required this.raw,
  });

  final String text;
  final CompositionReviewResult? review;
  final Map<String, dynamic> raw;
}
