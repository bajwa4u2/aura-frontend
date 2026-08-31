/// The unified worklist, client side.
///
/// Mirrors `admin/operator-work` on the server. The projection there indexes
/// work and decides nothing; this reads that index and decides nothing either.
/// Every item carries the destination that hands it back to the authority
/// which owns the decision.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/operator_capability.dart';

enum WorkSubjectKind { person, institution, media, content, unknown }

WorkSubjectKind _subjectKind(String? raw) => switch (raw) {
      'PERSON' => WorkSubjectKind.person,
      'INSTITUTION' => WorkSubjectKind.institution,
      'MEDIA' => WorkSubjectKind.media,
      'CONTENT' => WorkSubjectKind.content,
      _ => WorkSubjectKind.unknown,
    };

class OperatorWorkItem {
  const OperatorWorkItem({
    required this.key,
    required this.source,
    required this.sourceLabel,
    required this.id,
    required this.title,
    required this.state,
    required this.openedAt,
    required this.ageDays,
    required this.destination,
    required this.subjectKind,
    this.subjectLabel,
    this.subjectId,
    this.requiredCapability,
  });

  final String key;
  final String source;
  final String sourceLabel;
  final String id;
  final String title;

  /// The record's own state word, verbatim from its authority.
  final String state;

  final DateTime openedAt;

  /// Whole days waited. Never a deadline — Aura publishes no response
  /// commitment for these queues, and dressing age up as a breach would be
  /// inventing one.
  final int ageDays;

  final String destination;
  final WorkSubjectKind subjectKind;
  final String? subjectLabel;
  final String? subjectId;
  final OperatorCapability? requiredCapability;

  factory OperatorWorkItem.fromJson(Map<String, dynamic> json) {
    return OperatorWorkItem(
      key: json['key']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Work item',
      state: json['state']?.toString() ?? '',
      // Deliberately NOT converted to local time. Age is computed on the
      // server in whole days, and a local conversion here would only create a
      // second, disagreeing notion of when something opened.
      openedAt: DateTime.tryParse(json['openedAt']?.toString() ?? '') ??
          DateTime.now(),
      ageDays: (json['ageDays'] as num?)?.toInt() ?? 0,
      destination: json['destination']?.toString() ?? '',
      subjectKind: _subjectKind(json['subjectKind']?.toString()),
      subjectLabel: json['subjectLabel']?.toString(),
      subjectId: json['subjectId']?.toString(),
      requiredCapability:
          OperatorCapability.fromWire(json['requiredCapability']?.toString()),
    );
  }
}

class OperatorWorkSourceSummary {
  const OperatorWorkSourceSummary({
    required this.source,
    required this.label,
    required this.open,
    required this.readable,
    required this.destination,
    this.oldestAgeDays,
  });

  final String source;
  final String label;

  /// Open count. Meaningless when [readable] is false — the source failed and
  /// the console must say so rather than show a reassuring zero.
  final int open;

  final bool readable;
  final String destination;
  final int? oldestAgeDays;

  factory OperatorWorkSourceSummary.fromJson(Map<String, dynamic> json) {
    return OperatorWorkSourceSummary(
      source: json['source']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      open: (json['open'] as num?)?.toInt() ?? 0,
      readable: json['readable'] != false,
      destination: json['destination']?.toString() ?? '/admin/work',
      oldestAgeDays: (json['oldestAgeDays'] as num?)?.toInt(),
    );
  }
}

class OperatorWorkSummary {
  const OperatorWorkSummary({
    required this.sources,
    required this.totalOpen,
    required this.degradedSources,
  });

  final List<OperatorWorkSourceSummary> sources;

  /// Only readable, non-degraded sources. A total an operator can trust.
  final int totalOpen;

  final List<String> degradedSources;

  bool get isDegraded => degradedSources.isNotEmpty;

  /// True when every readable source is empty — a legitimate RESULT, not an
  /// empty state to apologise for.
  bool get isClear =>
      totalOpen == 0 && !isDegraded && sources.any((s) => s.readable);

  factory OperatorWorkSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['sources'];
    return OperatorWorkSummary(
      sources: raw is List
          ? raw
              .whereType<Map>()
              .map((e) =>
                  OperatorWorkSourceSummary.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      totalOpen: (json['totalOpen'] as num?)?.toInt() ?? 0,
      degradedSources: json['degradedSources'] is List
          ? (json['degradedSources'] as List)
              .map((e) => e.toString())
              .toList()
          : const [],
    );
  }
}

class OperatorWorkRepository {
  const OperatorWorkRepository(this._dio);

  final Dio _dio;

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  Future<OperatorWorkSummary> summary() async {
    final res = await _dio.get('/v1/admin/work/summary');
    return OperatorWorkSummary.fromJson(_asMap(res.data));
  }

  Future<List<OperatorWorkItem>> list({String? source, int? limit}) async {
    final res = await _dio.get('/v1/admin/work', queryParameters: {
      if (source != null) 'source': source,
      if (limit != null) 'limit': limit,
    });
    final body = _asMap(res.data);
    final items = body['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => OperatorWorkItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

final operatorWorkRepositoryProvider = Provider<OperatorWorkRepository>((ref) {
  return OperatorWorkRepository(ref.watch(dioProvider));
});

/// Per-source counts. Consumed by NOW and by the WORK filter bar alike, so the
/// number in the situation view and the number in the list cannot disagree.
final operatorWorkSummaryProvider =
    FutureProvider.autoDispose<OperatorWorkSummary>((ref) async {
  return ref.watch(operatorWorkRepositoryProvider).summary();
});

/// Currently selected source filter. Null means everything the operator holds.
final operatorWorkFilterProvider = StateProvider<String?>((_) => null);

final operatorWorkListProvider =
    FutureProvider.autoDispose<List<OperatorWorkItem>>((ref) async {
  final source = ref.watch(operatorWorkFilterProvider);
  return ref.watch(operatorWorkRepositoryProvider).list(source: source);
});
