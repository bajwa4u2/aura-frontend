/// THE OPERATOR WORKBENCH, CLIENT SIDE.
///
/// Mirrors `admin/operator-work` on the server. The projection there indexes
/// work and decides nothing; this reads that index and decides nothing either.
/// Every item carries the destination that hands it back to the authority
/// which owns the decision.
///
/// WHAT CHANGED, AND WHY
/// ---------------------
/// The first version modelled the worklist as an `AsyncValue`: data or error,
/// nothing between. So when one of seven authorities failed, the whole read
/// became an error, and four surfaces — NOW's attention, WORK, INTEGRITY's
/// conduct half, and every subject's waiting list — went dark together.
///
/// A worklist is never all-or-nothing. Seven independent authorities are
/// asked; some answer. This models that: [OperatorWorklist] carries the items
/// that arrived AND names the sources that did not, and the server now sends
/// exactly that. A partial worklist is better than a blank one — provided the
/// gap is declared, which is what `missing` is for.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/operator_capability.dart';
import '../domain/operator_signal.dart';
import 'operator_cache.dart';

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

/// Why a source could not be read, in words rather than a code.
String describeUnavailable(String? reason) => switch (reason) {
      'timed_out' => 'took too long to answer',
      'unreachable' => 'could not be reached',
      'authority_unavailable' => 'could not confirm what you may work on',
      _ => 'could not be read',
    };

/// One queue, and whether it answered.
class OperatorWorkSource {
  const OperatorWorkSource({
    required this.source,
    required this.label,
    required this.open,
    required this.readable,
    required this.destination,
    this.oldestAgeDays,
    this.unavailableReason,
  });

  final String source;
  final String label;

  /// Open count. MEANINGLESS when [readable] is false — the source failed, and
  /// the console must say so rather than show a reassuring zero.
  final int open;

  final bool readable;
  final String destination;
  final int? oldestAgeDays;

  /// Server-supplied reason. Never an exception string.
  final String? unavailableReason;

  /// What to tell the operator when this source did not answer.
  String get unavailableSentence =>
      '$label ${describeUnavailable(unavailableReason)}.';

  factory OperatorWorkSource.fromJson(Map<String, dynamic> json) {
    return OperatorWorkSource(
      source: json['source']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      open: (json['open'] as num?)?.toInt() ?? 0,
      readable: json['readable'] != false,
      destination: json['destination']?.toString() ?? '/admin/work',
      oldestAgeDays: (json['oldestAgeDays'] as num?)?.toInt(),
      unavailableReason: json['unavailableReason']?.toString(),
    );
  }
}

/// The situation across every queue this operator may work.
class OperatorWorkSummary {
  const OperatorWorkSummary({
    required this.sources,
    required this.totalOpen,
    required this.complete,
    this.authorityError,
  });

  final List<OperatorWorkSource> sources;

  /// Only readable sources. A total an operator can trust — and one they must
  /// be told is partial when [complete] is false.
  final int totalOpen;

  /// Every source answered. When false the count is real but not total, and
  /// the surface is required to say which queues are missing from it.
  final bool complete;

  /// Set when the operator's own authority could not be established. Different
  /// from a queue failing: nothing about their work is known at all.
  final String? authorityError;

  Iterable<OperatorWorkSource> get readable =>
      sources.where((s) => s.readable);

  Iterable<OperatorWorkSource> get unavailable =>
      sources.where((s) => !s.readable);

  /// Queues with something waiting, worst-waited first.
  List<OperatorWorkSource> get pressing {
    final busy = readable.where((s) => s.open > 0).toList();
    busy.sort((a, b) => (b.oldestAgeDays ?? 0).compareTo(a.oldestAgeDays ?? 0));
    return busy;
  }

  /// EVERY readable queue is empty. A real result, not an absence of one —
  /// and only claimable when nothing is missing.
  bool get isClear =>
      complete && totalOpen == 0 && readable.isNotEmpty;

  /// How well this reading is known, in the shared vocabulary.
  OperatorReach get reach {
    if (authorityError != null) return OperatorReach.unavailable;
    if (sources.isEmpty) return OperatorReach.unauthorized;
    if (!complete) return OperatorReach.partial;
    return OperatorReach.complete;
  }

  factory OperatorWorkSummary.fromJson(Map<String, dynamic> json) {
    final body = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final raw = body['sources'];
    final sources = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => OperatorWorkSource.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <OperatorWorkSource>[];

    // A SILENT ZERO IS THE WORST ANSWER AVAILABLE.
    //
    // This defaulted to 0 when the key was absent, and the WORK header then
    // read "All 0" directly above four open items — the console contradicting
    // itself on one screen. Absent means the server did not say, and the
    // honest fallback is the sum of what the readable sources DID report,
    // never a number that claims there is no work.
    final reported = (body['totalOpen'] as num?)?.toInt();
    final derived = sources
        .where((s) => s.readable)
        .fold<int>(0, (sum, s) => sum + (s.open > 0 ? s.open : 0));

    return OperatorWorkSummary(
      sources: sources,
      totalOpen: reported ?? derived,
      // Absent on an older server: infer completeness rather than claiming it.
      complete: body['complete'] as bool? ??
          (sources.isNotEmpty && sources.every((s) => s.readable)),
      authorityError: body['authorityError']?.toString(),
    );
  }
}

/// The items themselves, and what is missing from them.
class OperatorWorklist {
  const OperatorWorklist({
    required this.items,
    required this.missingSources,
    required this.complete,
    this.authorityError,
  });

  final List<OperatorWorkItem> items;

  /// Named, because a list six queues deep presented as seven is a lie of
  /// omission — and the most likely way an operator misses real work.
  ///
  /// These arrive as the stored source keys (`MODERATION`). The KEY is what
  /// travels, because it is stable and joins to the summary; turning it into
  /// the queue's own name is [labelFor]'s job, and a surface must never print
  /// the key at an operator.
  final List<String> missingSources;

  /// The queue's product name, resolved against a summary when one is at hand.
  ///
  /// Falls back to a readable form of the key rather than the key itself: a
  /// screen reading "MODERATION could not be read" is the console speaking
  /// schema at somebody who is trying to work.
  static String labelFor(String source, {OperatorWorkSummary? summary}) {
    for (final known in summary?.sources ?? const <OperatorWorkSource>[]) {
      if (known.source == source && known.label.trim().isNotEmpty) {
        return known.label;
      }
    }
    final words = source.replaceAll('_', ' ').toLowerCase();
    if (words.isEmpty) return source;
    return words[0].toUpperCase() + words.substring(1);
  }

  final bool complete;
  final String? authorityError;

  OperatorReach get reach {
    if (authorityError != null) return OperatorReach.unavailable;
    if (!complete) return OperatorReach.partial;
    return OperatorReach.complete;
  }

  factory OperatorWorklist.fromJson(Map<String, dynamic> json) {
    final body = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final raw = body['items'];
    final missing = body['unavailableSources'];

    return OperatorWorklist(
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => OperatorWorkItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      missingSources: missing is List
          ? missing.map((e) => e.toString()).toList()
          : const [],
      complete: body['complete'] as bool? ??
          (missing is! List || missing.isEmpty),
      authorityError: body['authorityError']?.toString(),
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

  Future<OperatorWorklist> list({String? source, int? limit}) async {
    final res = await _dio.get('/v1/admin/work', queryParameters: {
      if (source != null) 'source': source,
      if (limit != null) 'limit': limit,
    });
    return OperatorWorklist.fromJson(_asMap(res.data));
  }
}

final operatorWorkRepositoryProvider = Provider<OperatorWorkRepository>((ref) {
  return OperatorWorkRepository(ref.watch(dioProvider));
});

/// Per-source counts. Consumed by NOW and by the WORK filter bar alike, so the
/// number in the situation view and the number in the list cannot disagree.
///
/// Returns an [OperatorSignal] rather than throwing: a transport failure is
/// `unavailable`, which every surface knows how to render WITHOUT losing the
/// rest of itself. Nothing that reads this may go dark because of it.
final operatorWorkSummaryProvider =
    FutureProvider.autoDispose<OperatorSignal<OperatorWorkSummary>>((ref) async {
  // READ ONCE, SHOWN IN FOUR PLACES. NOW, WORK, INTEGRITY and both subject
  // areas all watch this; without a survival window, every move between them
  // disposed it and re-asked for the same answer behind a skeleton.
  cacheOperatorReading(ref);
  try {
    final summary = await ref.watch(operatorWorkRepositoryProvider).summary();
    final readAt = DateTime.now();

    return switch (summary.reach) {
      OperatorReach.partial => OperatorSignal.partial(
          summary,
          missing: summary.unavailable.map((s) => s.label).toList(),
          readAt: readAt,
        ),
      OperatorReach.unavailable => OperatorSignal.unavailable(
          detail: describeUnavailable(summary.authorityError),
        ),
      OperatorReach.unauthorized =>
        const OperatorSignal.unauthorized(needs: 'any operator queue'),
      _ => OperatorSignal.complete(summary, readAt: readAt),
    };
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return const OperatorSignal.unauthorized(needs: 'operator work');
    }
    return const OperatorSignal.unavailable(detail: 'could not be read');
  }
});

/// Currently selected source filter. Null means everything the operator holds.
final operatorWorkFilterProvider = StateProvider<String?>((_) => null);

final operatorWorkListProvider =
    FutureProvider.autoDispose<OperatorSignal<OperatorWorklist>>((ref) async {
  cacheOperatorReading(ref);
  final source = ref.watch(operatorWorkFilterProvider);
  try {
    final list =
        await ref.watch(operatorWorkRepositoryProvider).list(source: source);
    final readAt = DateTime.now();
    if (list.authorityError != null) {
      return OperatorSignal.unavailable(
        detail: describeUnavailable(list.authorityError),
      );
    }
    // NAMED, NOT KEYED. The list envelope carries stable source keys; the
    // disclosure an operator reads must carry the queue's own name, or the
    // screen says "MODERATION could not be read" at somebody trying to work.
    // The summary is already loaded beside this on every surface that shows
    // the disclosure, so no extra request is made to resolve them.
    final summary = ref.read(operatorWorkSummaryProvider).valueOrNull?.value;

    return list.complete
        ? OperatorSignal.complete(list, readAt: readAt)
        : OperatorSignal.partial(
            list,
            missing: list.missingSources
                .map((s) => OperatorWorklist.labelFor(s, summary: summary))
                .toList(),
            readAt: readAt,
          );
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return const OperatorSignal.unauthorized(needs: 'operator work');
    }
    return const OperatorSignal.unavailable(detail: 'could not be read');
  }
});
