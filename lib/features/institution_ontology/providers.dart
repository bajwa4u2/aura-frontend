import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'models.dart';

/// Curated Institution Ontology — read-only FutureProvider.
///
/// Fetches `/v1/institutions/ontology` once and caches the curated
/// taxonomy for the session. Edit / discovery surfaces consume this
/// provider; UI never hardcodes the class / type / tag list. When a
/// new class is added on the backend, clients pick it up on next
/// reload without a code change.
final institutionOntologyProvider =
    FutureProvider<InstitutionOntology>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/institutions/ontology');
  return InstitutionOntology.fromJson(res.data);
});
