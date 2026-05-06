import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/monetization_repository.dart';
import '../domain/monetization_models.dart';

final monetizationConfigProvider =
    FutureProvider<MonetizationConfig>((ref) async {
  final repo = ref.watch(monetizationRepositoryProvider);
  return repo.fetchConfig();
});

final institutionEntitlementProvider =
    FutureProvider.family<InstitutionEntitlements, String>(
        (ref, institutionId) async {
  final repo = ref.watch(monetizationRepositoryProvider);
  return repo.fetchInstitutionEntitlements(institutionId);
});
