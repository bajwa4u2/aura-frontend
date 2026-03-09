import 'package:dio/dio.dart';

class InstitutionDomainsRepository {
  InstitutionDomainsRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> getMyInstitution() async {
    final res = await _dio.get('/institutions/me');
    final data = _asMap(res.data) ?? <String, dynamic>{};

    final topInstitution = _asMap(data['institution']);
    final membership = _asMap(data['membership']);
    final membershipInstitution = _asMap(membership?['institution']);
    final request = _asMap(data['request']);

    return topInstitution ?? membershipInstitution ?? request;
  }

  Future<List<Map<String, dynamic>>> getDomains(String institutionId) async {
    final res = await _dio.get('/institutions/$institutionId/domains');
    final data = _asMap(res.data) ?? <String, dynamic>{};

    return _asMapList(data['domains']);
  }

  Future<void> addDomain(String institutionId, String domain) async {
    await _dio.post(
      '/institutions/$institutionId/domains',
      data: {'domain': domain},
    );
  }

  Future<void> removeDomain(String institutionId, String domainId) async {
    await _dio.delete('/institutions/$institutionId/domains/$domainId');
  }

  Future<Map<String, dynamic>> issueDnsChallenge(
      String institutionId, String domainId) async {
    final res = await _dio.post(
      '/institutions/$institutionId/domains/$domainId/verify/dns',
    );

    final data = _asMap(res.data) ?? <String, dynamic>{};
    return _asMap(data['verification']) ?? <String, dynamic>{};
  }

  Future<bool> verifyDomain(String institutionId, String domainId) async {
    final res = await _dio.post(
      '/institutions/$institutionId/domains/$domainId/verify/check',
    );

    final data = _asMap(res.data) ?? <String, dynamic>{};
    return data['verified'] == true;
  }
}