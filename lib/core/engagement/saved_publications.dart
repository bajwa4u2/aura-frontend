import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'engagement_model.dart';

/// One thing a person kept, whatever kind of publication it was.
///
/// The personal Saved experience read a Post-only endpoint, so an article
/// somebody deliberately saved never appeared there and an announcement could
/// not be kept at all. Storage was generalised while the surface that exists to
/// show it stayed a Post-era consumer.
class SavedPublication {
  const SavedPublication({
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.savedAt,
    this.subtitle,
    this.route,
  });

  final PublicationTarget targetType;
  final String targetId;
  final String title;
  final String? subtitle;
  final String? route;
  final DateTime? savedAt;

  /// How this kind of thing is named to a reader.
  String get kindLabel => switch (targetType) {
        PublicationTarget.post => 'Post',
        PublicationTarget.institutionPost => 'Institution post',
        PublicationTarget.article => 'Article',
        PublicationTarget.announcement => 'Announcement',
      };

  static SavedPublication? fromJson(Map<String, dynamic> j) {
    final wire = (j['targetType'] ?? '').toString().toUpperCase();
    PublicationTarget? kind;
    for (final t in PublicationTarget.values) {
      if (t.wireValue == wire) kind = t;
    }
    // A class this client does not know is skipped rather than guessed at — a
    // newer server may save kinds an older client cannot render.
    if (kind == null) return null;
    return SavedPublication(
      targetType: kind,
      targetId: (j['targetId'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      subtitle: (j['subtitle'] ?? '').toString().isEmpty
          ? null
          : j['subtitle'].toString(),
      route: (j['route'] ?? '').toString().isEmpty ? null : j['route'].toString(),
      savedAt: j['savedAt'] == null
          ? null
          : DateTime.tryParse(j['savedAt'].toString()),
    );
  }
}

/// Everything this person has saved, newest first, across every class.
final savedPublicationsProvider =
    FutureProvider.autoDispose<List<SavedPublication>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final res = await dio.get<dynamic>('/engagement/saved');
    final root = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
    final payload = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    final items = payload['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((m) => SavedPublication.fromJson(Map<String, dynamic>.from(m)))
        .whereType<SavedPublication>()
        .toList(growable: false);
  } on DioException {
    // Saved is a reading convenience; a failure here must not take the screen
    // down, and the Post-only list still renders beneath it.
    return const [];
  }
});
