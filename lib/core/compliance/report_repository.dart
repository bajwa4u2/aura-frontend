import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';

/// Apple Store §1.2 UGC compliance — types and HTTP client for the
/// generic content-report flow.
///
/// Every public UGC surface (post detail, post card, comment widget,
/// profile menu) routes through `ReportContentSheet` → this
/// repository → `POST /v1/moderation/reports`. The backend already
/// owns the storage shape (`ModerationReport`) + the moderator queue
/// + admin-action endpoints; the frontend just files reports with a
/// typed reason.

enum ReportTargetType {
  post,
  reply,
  user,
  message,
  institution,
}

extension ReportTargetTypeWire on ReportTargetType {
  String get wire {
    switch (this) {
      case ReportTargetType.post:
        return 'POST';
      case ReportTargetType.reply:
        return 'REPLY';
      case ReportTargetType.user:
        return 'USER';
      case ReportTargetType.message:
        return 'MESSAGE';
      case ReportTargetType.institution:
        return 'INSTITUTION';
    }
  }
}

enum ReportReason {
  harassment,
  hate,
  sexual,
  violence,
  spam,
  other,
}

extension ReportReasonMeta on ReportReason {
  /// Wire token — the backend stores the raw reason string. Keeping
  /// these stable across releases gives the moderation queue a clean
  /// histogram per reason category.
  String get wire {
    switch (this) {
      case ReportReason.harassment:
        return 'HARASSMENT_OR_ABUSE';
      case ReportReason.hate:
        return 'HATE_OR_OFFENSIVE';
      case ReportReason.sexual:
        return 'SEXUAL_CONTENT';
      case ReportReason.violence:
        return 'VIOLENCE_OR_THREAT';
      case ReportReason.spam:
        return 'SPAM_OR_SCAM';
      case ReportReason.other:
        return 'OTHER';
    }
  }

  String get label {
    switch (this) {
      case ReportReason.harassment:
        return 'Harassment or abuse';
      case ReportReason.hate:
        return 'Hate or offensive content';
      case ReportReason.sexual:
        return 'Sexual content';
      case ReportReason.violence:
        return 'Violence or threat';
      case ReportReason.spam:
        return 'Spam or scam';
      case ReportReason.other:
        return 'Other';
    }
  }
}

class ReportRepository {
  ReportRepository(this._dio);

  final Dio _dio;

  /// File a moderation report. The endpoint is authoritative on
  /// dedup/throttling; this client is fire-and-forget on the success
  /// path and surfaces only the bare result.
  Future<Map<String, dynamic>> create({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) async {
    final res = await _dio.post(
      '/moderation/reports',
      data: {
        'targetType': targetType.wire,
        'targetId': targetId,
        'reason': reason.wire,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
    final body = res.data;
    if (body is Map<String, dynamic>) return body;
    return <String, dynamic>{};
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.read(dioProvider)),
);
