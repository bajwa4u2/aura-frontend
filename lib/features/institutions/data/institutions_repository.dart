import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/institution.dart';

final institutionsRepositoryProvider = Provider<InstitutionsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InstitutionsRepository(dio);
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
}