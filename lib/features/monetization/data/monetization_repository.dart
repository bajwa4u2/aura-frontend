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
      data: {'institutionId': institutionId.trim(), 'productCode': productCode},
    );
    return _checkoutFrom(res.data);
  }

  Future<CheckoutSession> startInstitutionCreditsCheckout({
    required String institutionId,
    required String productCode,
  }) async {
    final res = await _dio.post(
      '/monetization/checkout/institution-credits',
      data: {'institutionId': institutionId.trim(), 'productCode': productCode},
    );
    return _checkoutFrom(res.data);
  }

  /// The institution's latest grant request, or null if it never asked.
  Future<InstitutionGrant?> fetchInstitutionGrant(String institutionId) async {
    final res = await _dio.get(
      '/monetization/institutions/${institutionId.trim()}/grant',
    );
    final payload = _unwrap(res.data);
    if (payload is Map && payload.isNotEmpty) {
      return InstitutionGrant.fromJson(Map<String, dynamic>.from(payload));
    }
    return null;
  }

  Future<void> requestInstitutionGrant({
    required String institutionId,
    required String requestedTier,
    String? message,
  }) async {
    await _dio.post(
      '/monetization/institutions/${institutionId.trim()}/grant-request',
      data: {
        'requestedTier': requestedTier,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );
  }

  /// A one-time link to the billing provider's own page, where the plan,
  /// card, invoices and cancellation are managed.
  Future<String?> openBillingPortal(String institutionId) async {
    final res = await _dio.post(
      '/monetization/institutions/${institutionId.trim()}/billing-portal',
    );
    final payload = _unwrap(res.data);
    if (payload is Map) return payload['url'] as String?;
    return null;
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
