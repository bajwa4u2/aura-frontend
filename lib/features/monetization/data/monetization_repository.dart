import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/monetization_models.dart';

final monetizationRepositoryProvider = Provider<MonetizationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MonetizationRepository(dio);
});

class MonetizationRepository {
  MonetizationRepository(this._dio);

  final dynamic _dio;

  Future<MonetizationConfig> fetchConfig() async {
    final res = await _dio.get('/monetization/config');
    final payload = _unwrap(res.data);
    if (payload is Map) {
      return MonetizationConfig.fromJson(Map<String, dynamic>.from(payload));
    }
    throw Exception('Unexpected monetization config response.');
  }

  Future<InstitutionEntitlements> fetchInstitutionEntitlements(
    String institutionId,
  ) async {
    final id = institutionId.trim();
    if (id.isEmpty) {
      throw ArgumentError('institutionId is required');
    }
    final res = await _dio.get('/monetization/institutions/$id/entitlements');
    final payload = _unwrap(res.data);
    if (payload is Map) {
      return InstitutionEntitlements.fromJson(
        Map<String, dynamic>.from(payload),
      );
    }
    throw Exception('Unexpected entitlements response.');
  }

  Future<CheckoutSession> startInstitutionPlanCheckout({
    required String institutionId,
    required String productCode,
  }) async {
    final res = await _dio.post(
      '/monetization/checkout/institution-plan',
      data: {
        'institutionId': institutionId.trim(),
        'productCode': productCode,
      },
    );
    return _checkoutFrom(res.data);
  }

  Future<CheckoutSession> startInstitutionCreditsCheckout({
    required String institutionId,
    required String productCode,
  }) async {
    final res = await _dio.post(
      '/monetization/checkout/institution-credits',
      data: {
        'institutionId': institutionId.trim(),
        'productCode': productCode,
      },
    );
    return _checkoutFrom(res.data);
  }

  CheckoutSession _checkoutFrom(dynamic raw) {
    final payload = _unwrap(raw);
    if (payload is Map) {
      return CheckoutSession.fromJson(Map<String, dynamic>.from(payload));
    }
    throw Exception('Unexpected checkout response.');
  }

  // Backend wraps successful responses as { ok: true, data: <payload> }.
  dynamic _unwrap(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      if (m.containsKey('data')) return m['data'];
      return m;
    }
    return raw;
  }
}
