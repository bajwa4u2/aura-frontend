import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is! Map) throw Exception('Unexpected response');

    final m = Map<String, dynamic>.from(raw as Map);

    // Locked envelope (Aura Contract v1)
    if (m['ok'] == true && m.containsKey('data')) {
      final inner = m['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner as Map);
      return {'value': inner};
    }

    // Legacy fallback
    if (m['data'] is Map) return Map<String, dynamic>.from(m['data'] as Map);

    return m;
  }

/// Riverpod provider for AuthRepository (was missing).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.read(dioProvider);
  return AuthRepository(dio);
});