/// WHETHER TO DRAW THE DOOR.
///
/// The console had no discoverable entrance. The shell's admin flag came from
/// a cache populated only by a probe that fires on entering `/admin` — so an
/// operator could not see the way in until they had already found it by
/// typing the address. The founder, holding OWNER, had exactly that
/// experience.
///
/// This asks the one small question that is safe to ask of every signed-in
/// person: may they enter? It carries no permissions, writes no audit denial,
/// and costs one indexed lookup. Capability truth still comes from
/// `/v1/admin/me` behind the real guard, once they are inside.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';

/// True only when the person holds at least one operator capability.
///
/// Defaults to FALSE on every failure. A door drawn in error sends somebody to
/// a refusal; a door not drawn costs an operator one typed address. The
/// asymmetry decides it.
final operatorEntryProvider = FutureProvider<bool>((ref) async {
  final status = ref.watch(authStatusProvider);
  if (status != AuthStatus.authed) return false;

  try {
    final res = await ref.watch(dioProvider).get('/v1/admin/entry');
    final data = res.data;
    final body = data is Map
        ? Map<String, dynamic>.from(
            data['data'] is Map ? data['data'] as Map : data,
          )
        : const <String, dynamic>{};
    return body['operator'] == true;
  } on DioException {
    return false;
  } catch (_) {
    return false;
  }
});

/// Synchronous form for shells that must decide during build.
///
/// Absent an answer it says false, which is the same asymmetry: the entrance
/// appears a moment late rather than appearing wrongly.
final canEnterOperatorConsoleProvider = Provider<bool>((ref) {
  return ref.watch(operatorEntryProvider).maybeWhen(
        data: (canEnter) => canEnter,
        orElse: () => false,
      );
});
