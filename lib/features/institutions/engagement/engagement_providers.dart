import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import 'engagement_models.dart';
import 'engagement_repository.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return EngagementRepository(dio);
});

final engagementListProvider =
    FutureProvider.family<List<RoutedRecord>, String>(
        (ref, institutionId) async {
  final repo = ref.watch(engagementRepositoryProvider);
  return repo.list(institutionId);
});

/// The list narrowed to one status (null = everything), for the Questions
/// screen's filters (2026-10-09).
final engagementFilteredListProvider =
    FutureProvider.family<List<RoutedRecord>, (String, String?)>((ref, args) async {
  final (institutionId, status) = args;
  final repo = ref.watch(engagementRepositoryProvider);
  return repo.list(institutionId, status: status);
});

final engagementSummaryProvider =
    FutureProvider.family<EngagementSummary, String>(
        (ref, institutionId) async {
  final repo = ref.watch(engagementRepositoryProvider);
  return repo.getSummary(institutionId);
});

final engagementDetailProvider =
    FutureProvider.family<RoutedRecord, (String, String)>((ref, args) async {
  final (institutionId, recordId) = args;
  final repo = ref.watch(engagementRepositoryProvider);
  return repo.getDetail(institutionId, recordId);
});
