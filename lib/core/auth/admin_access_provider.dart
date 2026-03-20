import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_bootstrap.dart';
import '../auth/session_providers.dart';
import '../net/dio_provider.dart';

const String _adminUserIds =
    String.fromEnvironment('AURA_ADMIN_USER_IDS', defaultValue: '');

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

List<String> _adminUserIdList() {
  return _adminUserIds
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapMe(dynamic raw) {
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

final appAdminAccessProvider = FutureProvider<AppAdminAccess>((ref) async {
  await ref.watch(sessionBootstrapProvider.future);

  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) {
    return const AppAdminAccess(state: AppAdminState.none);
  }

  final dio = ref.watch(dioProvider);

  try {
    final res = await dio.get('/users/me');
    final me = _unwrapMe(res.data);

    final role = (me['role'] ?? '').toString().trim().toLowerCase();
    if (role == 'admin') {
      return AppAdminAccess(
        state: AppAdminState.admin,
        me: me,
      );
    }

    final id = (me['id'] ?? '').toString().trim();
    if (id.isNotEmpty && _adminUserIdList().contains(id)) {
      return AppAdminAccess(
        state: AppAdminState.admin,
        me: me,
      );
    }

    return AppAdminAccess(
      state: AppAdminState.none,
      me: me,
    );
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return const AppAdminAccess(state: AppAdminState.none);
    }
    rethrow;
  }
});
