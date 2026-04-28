import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_bootstrap.dart';
import '../auth/session_providers.dart';
import '../net/dio_provider.dart';

enum AppAdminState {
  none,
  admin,
}

class AppAdminAccess {
  final AppAdminState state;
  final Map<String, dynamic>? me;

  const AppAdminAccess({
    required this.state,
    this.me,
  });

  bool get isAdmin => state == AppAdminState.admin;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapAdminMe(dynamic raw) {
  final root = _asMap(raw);

  final user = root['user'];
  if (user is Map) return Map<String, dynamic>.from(user);

  final data = root['data'];
  if (data is Map) {
    final nested = Map<String, dynamic>.from(data);
    final nestedUser = nested['user'];
    if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
    return nested;
  }

  return root;
}

/// Backend-hydrated admin access.
/// Authority is derived exclusively from GET /v1/admin/me.
/// 403 / 404 means the user has no admin grant — treated as none, not a crash.
final appAdminAccessProvider = FutureProvider<AppAdminAccess>((ref) async {
  await ref.watch(sessionBootstrapProvider.future);

  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) {
    return const AppAdminAccess(state: AppAdminState.none);
  }

  final dio = ref.watch(dioProvider);

  try {
    final res = await dio.get('/v1/admin/me');
    final me = _unwrapAdminMe(res.data);
    return AppAdminAccess(state: AppAdminState.admin, me: me);
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403 || code == 404) {
      return const AppAdminAccess(state: AppAdminState.none);
    }
    rethrow;
  }
});
