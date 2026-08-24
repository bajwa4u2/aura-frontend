import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/person_identity_model.dart';
import '../../../core/net/dio_provider.dart';

/// DISCOVER → PEOPLE, the projection.
///
/// Extracted from the People screen so the Discover landing can surface the
/// same suggestions without a second request path or a second reading of the
/// payload. One projection, two presentations — a landing strip and the full
/// domain screen — and neither can drift from the other's idea of who a
/// suggested person is.
///
/// The suggestions themselves come from the canonical `/discover/people`
/// projection, which is deterministic, explainable and privacy-safe. Nothing
/// here ranks, scores or personalises on the client; it reads what the server
/// already decided is discoverable and renders it.
class PersonSuggestion {
  const PersonSuggestion({
    required this.person,
    required this.reasons,
    required this.followState,
  });

  /// THE PERSON, WHOLE — the canonical identity, not scalars copied off it.
  /// Holding the identity itself is what keeps a suggested person rendering
  /// with the same name and verification they carry everywhere else.
  final AuraPersonIdentity person;

  /// Discovery state — what this surface adds, never who the person is.
  final List<String> reasons;
  final String followState;

  String get userId => person.userId;
  String? get handle => person.handle.isEmpty ? null : person.handle;
  String get displayName => person.label;

  static PersonSuggestion fromJson(Map<String, dynamic> json) =>
      PersonSuggestion(
        person: AuraPersonIdentity.fromJson(json),
        reasons: (json['reasons'] as List<dynamic>? ?? const [])
            .map((r) => r.toString())
            .toList(),
        followState: (json['followState'] ?? 'NONE').toString(),
      );
}

class PeopleDiscoveryPage {
  const PeopleDiscoveryPage({required this.suggestions, required this.coldStart});

  final List<PersonSuggestion> suggestions;

  /// The server has nothing personal to go on yet. A truthful state of its
  /// own — not an error, and not an empty result dressed up as one.
  final bool coldStart;
}

final peopleDiscoveryProvider =
    FutureProvider.autoDispose<PeopleDiscoveryPage>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<dynamic>('/discover/people');
  final data = res.data is Map<String, dynamic> &&
          (res.data as Map<String, dynamic>)['data'] is Map<String, dynamic>
      ? (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>
      : res.data as Map<String, dynamic>;
  return PeopleDiscoveryPage(
    coldStart: data['coldStart'] == true,
    suggestions: (data['suggestions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PersonSuggestion.fromJson)
        .toList(),
  );
});
