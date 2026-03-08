import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/institution.dart';

final institutionsRepositoryProvider = Provider<InstitutionsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InstitutionsRepository(dio);
});

final pendingInstitutionRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listVerificationRequests(status: 'UNDER_REVIEW');
});

final verifiedInstitutionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutions(status: 'VERIFIED');
});

final suspendedInstitutionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutions(status: 'SUSPENDED');
});

final rejectedInstitutionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutions(status: 'REJECTED');
});

final approveInstitutionRequestProvider =
    FutureProvider.family<void, String>((ref, requestId) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  await repo.approveVerificationRequest(requestId);
});

final rejectInstitutionRequestProvider =
    FutureProvider.family<void, String>((ref, requestId) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  await repo.rejectVerificationRequest(requestId);
});

class InstitutionsRepository {
  InstitutionsRepository(this._dio);

  final dynamic _dio;

  Future<Institution> getBySlug(String slug) async {
    final cleanSlug = slug.trim();
    if (cleanSlug.isEmpty) {
      throw Exception('Institution slug is missing.');
    }

    final res = await _dio.get('/institutions/$cleanSlug');
    final body = res.data;

    if (body is Map) {
      final root = Map<String, dynamic>.from(body);

      final directInstitution = root['institution'];
      if (directInstitution is Map) {
        return Institution.fromJson(
          Map<String, dynamic>.from(directInstitution),
        );
      }

      final data = root['data'];
      if (data is Map) {
        final dataMap = Map<String, dynamic>.from(data);

        final nestedInstitution = dataMap['institution'];
        if (nestedInstitution is Map) {
          return Institution.fromJson(
            Map<String, dynamic>.from(nestedInstitution),
          );
        }

        return Institution.fromJson(dataMap);
      }

      final item = root['item'];
      if (item is Map) {
        return Institution.fromJson(
          Map<String, dynamic>.from(item),
        );
      }

      return Institution.fromJson(root);
    }

    throw Exception('Unexpected institution response.');
  }

  Future<List<Map<String, dynamic>>> listVerificationRequests({
    required String status,
  }) async {
    final res = await _dio.get(
      '/institutions/admin/verification-requests',
      queryParameters: {'status': status},
    );
    return _readItems(res.data);
  }

  Future<List<Map<String, dynamic>>> listInstitutions({
    required String status,
  }) async {
    final res = await _dio.get(
      '/institutions/admin',
      queryParameters: {'status': status},
    );
    return _readItems(res.data);
  }

  Future<void> approveVerificationRequest(String requestId) async {
    final id = requestId.trim();
    if (id.isEmpty) {
      throw Exception('Request id is missing.');
    }

    await _dio.post('/institutions/admin/verification-requests/$id/approve');
  }

  Future<void> rejectVerificationRequest(String requestId) async {
    final id = requestId.trim();
    if (id.isEmpty) {
      throw Exception('Request id is missing.');
    }

    await _dio.post('/institutions/admin/verification-requests/$id/reject');
  }

  List<Map<String, dynamic>> _readItems(dynamic body) {
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);

      final directItems = root['items'];
      if (directItems is List) {
        return directItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final data = root['data'];
      if (data is Map) {
        final dataMap = Map<String, dynamic>.from(data);

        final nestedItems = dataMap['items'];
        if (nestedItems is List) {
          return nestedItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }

    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }
}