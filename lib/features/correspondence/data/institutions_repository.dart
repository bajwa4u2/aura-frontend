import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

List<Map<String, dynamic>> _itemsFromResponse(dynamic raw) {
  if (raw is Map && raw['items'] is List) {
    return (raw['items'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  if (raw is Map && raw['data'] is Map) {
    final data = raw['data'];
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  return <Map<String, dynamic>>[];
}

final pendingInstitutionRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res =
      await dio.get('/institutions/admin/verification-requests?status=PENDING');
  return _itemsFromResponse(res.data);
});

final verifiedInstitutionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/institutions/admin?status=VERIFIED');
  return _itemsFromResponse(res.data);
});

final suspendedInstitutionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/institutions/admin?status=SUSPENDED');
  return _itemsFromResponse(res.data);
});

final rejectedInstitutionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/institutions/admin?status=REJECTED');
  return _itemsFromResponse(res.data);
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