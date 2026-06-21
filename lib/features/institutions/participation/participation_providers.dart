import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import 'participation_models.dart';
import 'participation_repository.dart';

final participationRepositoryProvider =
    Provider<ParticipationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ParticipationRepository(dio);
});

final participationListProvider = FutureProvider.family<
    List<InstitutionParticipation>, String>((ref, institutionId) async {
  final repo = ref.watch(participationRepositoryProvider);
  return repo.list(institutionId);
});
