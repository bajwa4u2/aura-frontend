import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/person_identity_model.dart';
import '../../../core/net/dio_provider.dart';

/// PERSONAL CONTINUITY — what happened, with no unread semantics.
///
/// Founder ruling (2026-08-23). Activity holds two semantically distinct
/// views, and this is the one that is NOT an inbox: history rows carry no read
/// state, reading them acknowledges nothing, and they never contribute to the
/// attention signal.
///
/// THE AUDIENCE POLICY IS THE SERVER'S. This client does no filtering of its
/// own and must not: a rule enforced in a widget is a rule anyone can skip by
/// calling the endpoint. What arrives here has already been scoped to
/// correspondences the person is currently party to, and to events that are
/// genuinely their own continuity.
class ActivityHistoryItem {
  const ActivityHistoryItem({
    required this.id,
    required this.activityType,
    required this.occurredAt,
    required this.actor,
    required this.target,
    required this.conversationId,
    required this.contextName,
    required this.destination,
  });

  final String id;
  final String activityType;
  final DateTime? occurredAt;

  /// Canonical person identity — the same reader every other surface uses, so
  /// an actor looks the same here as on Members or in a conversation.
  final AuraPersonIdentity actor;
  final AuraPersonIdentity target;

  final String conversationId;
  final String? contextName;

  /// Where this can be opened, or null when nothing survives to open. A
  /// history row stays true about the past even when its destination is gone.
  final String? destination;

  bool get hasDestination => (destination ?? '').trim().isNotEmpty;

  static ActivityHistoryItem fromJson(Map<String, dynamic> json) {
    final context = json['context'] is Map
        ? Map<String, dynamic>.from(json['context'] as Map)
        : const <String, dynamic>{};
    return ActivityHistoryItem(
      id: (json['id'] ?? '').toString(),
      activityType: (json['activityType'] ?? '').toString(),
      occurredAt: DateTime.tryParse((json['occurredAt'] ?? '').toString()),
      actor: AuraPersonIdentity.fromJson(json['actor']),
      target: AuraPersonIdentity.fromJson(json['target']),
      conversationId: (context['conversationId'] ?? '').toString(),
      contextName: (context['name'] as String?)?.trim().isEmpty ?? true
          ? null
          : (context['name'] as String).trim(),
      destination: (json['destination'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['destination'] as String).trim(),
    );
  }
}

class ActivityHistoryPage {
  const ActivityHistoryPage({required this.items, required this.nextCursor});

  final List<ActivityHistoryItem> items;

  /// The backend's keyset cursor. Passed back verbatim — deriving a cursor
  /// from the last item's timestamp would quietly break the total ordering
  /// the server established.
  final String? nextCursor;

  bool get hasMore => (nextCursor ?? '').isNotEmpty;
}

class ActivityHistoryRepository {
  ActivityHistoryRepository(this._ref);

  final Ref _ref;

  Future<ActivityHistoryPage> page({String? cursor, int limit = 30}) async {
    final res = await _ref.read(dioProvider).get(
      '/activity/history',
      queryParameters: {
        'limit': limit,
        if ((cursor ?? '').isNotEmpty) 'cursor': cursor,
      },
    );

    final body = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;

    final raw = data['items'];
    return ActivityHistoryPage(
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => ActivityHistoryItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
      nextCursor: (data['nextCursor'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['nextCursor'] as String).trim(),
    );
  }
}

final activityHistoryRepositoryProvider = Provider(
  (ref) => ActivityHistoryRepository(ref),
);

/// The first page. Further pages are appended by the screen's own controller,
/// which owns the accumulated list — a provider that refetched everything on
/// each page would lose the reader's position.
final activityHistoryFirstPageProvider =
    FutureProvider.autoDispose<ActivityHistoryPage>((ref) async {
  return ref.read(activityHistoryRepositoryProvider).page();
});
