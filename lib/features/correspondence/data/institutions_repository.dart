import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/net/dio_provider.dart';

final pendingInstitutionRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);

  final res =
      await dio.get('/institutions/admin/verification-requests?status=PENDING');

  final data = res.data;

  if (data is Map && data['items'] is List) {
    return List<Map<String, dynamic>>.from(data['items']);
  }

  return [];
});

final approveInstitutionRequestProvider =
    FutureProvider.family<void, String>((ref, id) async {
  final dio = ref.read(dioProvider);
  await dio.post('/institutions/admin/verification-requests/$id/approve');
});

final rejectInstitutionRequestProvider =
    FutureProvider.family<void, String>((ref, id) async {
  final dio = ref.read(dioProvider);
  await dio.post('/institutions/admin/verification-requests/$id/reject');
});