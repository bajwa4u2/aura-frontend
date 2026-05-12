// AI Content Reports — client-side wrapper for POST /v1/ai/reports.
//
// Microsoft Store §11.16 (Live Generative AI Content) compliance: every
// AI response surface (Aura Support AI today; future AI assistants
// later) must let the user flag an inappropriate response. This
// repository is the single point that talks to the backend report
// endpoint so the UI layer doesn't reinvent the envelope/error shape.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

/// Mirrors the backend `AIReportCategory` enum. Order is the order the
/// user sees in the report sheet.
enum AiReportCategory {
  harmfulOrUnsafe,
  harassmentOrHate,
  falseOrMisleading,
  sexualOrInappropriate,
  violenceOrSelfHarm,
  spamOrAbuse,
  other,
}

extension AiReportCategoryX on AiReportCategory {
  /// Wire value the backend DTO accepts.
  String get wireValue {
    switch (this) {
      case AiReportCategory.harmfulOrUnsafe:
        return 'HARMFUL_OR_UNSAFE';
      case AiReportCategory.harassmentOrHate:
        return 'HARASSMENT_OR_HATE';
      case AiReportCategory.falseOrMisleading:
        return 'FALSE_OR_MISLEADING';
      case AiReportCategory.sexualOrInappropriate:
        return 'SEXUAL_OR_INAPPROPRIATE';
      case AiReportCategory.violenceOrSelfHarm:
        return 'VIOLENCE_OR_SELF_HARM';
      case AiReportCategory.spamOrAbuse:
        return 'SPAM_OR_ABUSE';
      case AiReportCategory.other:
        return 'OTHER';
    }
  }

  /// User-facing label rendered in the report sheet.
  String get label {
    switch (this) {
      case AiReportCategory.harmfulOrUnsafe:
        return 'Harmful or unsafe';
      case AiReportCategory.harassmentOrHate:
        return 'Harassment or hate';
      case AiReportCategory.falseOrMisleading:
        return 'False or misleading';
      case AiReportCategory.sexualOrInappropriate:
        return 'Sexual or inappropriate';
      case AiReportCategory.violenceOrSelfHarm:
        return 'Violence or self-harm';
      case AiReportCategory.spamOrAbuse:
        return 'Spam or abuse';
      case AiReportCategory.other:
        return 'Other';
    }
  }
}

class AiReportResult {
  const AiReportResult({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

class AiReportsRepository {
  AiReportsRepository(this._dio);

  final Dio _dio;

  /// Submits a single report against an AI response.
  ///
  /// The `contentSnapshot` MUST contain the exact assistant text the
  /// user is reporting on — the backend persists this so the record is
  /// independently meaningful even if the conversation is later
  /// deleted or the AI generation is repeated and produces different
  /// text. Optional fields scope the report (conversationId,
  /// messageId, surface) so operators can group reports by AI feature.
  Future<AiReportResult> submit({
    required AiReportCategory category,
    required String contentSnapshot,
    String? note,
    String? conversationId,
    String? messageId,
    String? surface,
    Map<String, dynamic>? metadata,
  }) async {
    final res = await _dio.post(
      '/ai/reports',
      data: <String, dynamic>{
        'category': category.wireValue,
        'contentSnapshot': contentSnapshot,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (conversationId != null && conversationId.isNotEmpty)
          'conversationId': conversationId,
        if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
        if (surface != null && surface.isNotEmpty) 'surface': surface,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
    );
    final inner = _unwrap(res.data);
    return AiReportResult(
      id: (inner['id'] as String? ?? '').trim(),
      createdAt: inner['createdAt'] is String
          ? DateTime.tryParse(inner['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

Map<String, dynamic> _unwrap(dynamic raw) {
  if (raw is Map) {
    final outer = Map<String, dynamic>.from(raw);
    final inner = outer['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return outer;
  }
  return <String, dynamic>{};
}

final aiReportsRepositoryProvider = Provider<AiReportsRepository>((ref) {
  return AiReportsRepository(ref.watch(dioProvider));
});
