import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'compatibility_models.dart';
import 'compatibility_repository.dart';

/// Periodic refresh cadence. Long enough that a healthy app makes only ~6
/// requests per hour, short enough that an admin flipping `maintenanceMode`
/// reaches every active client within ~10 minutes without a server-side push.
const Duration _kRefreshInterval = Duration(minutes: 10);

final compatibilityRepositoryProvider = Provider<CompatibilityRepository>((
  ref,
) {
  final dio = ref.watch(dioProvider);
  return CompatibilityRepository(dio);
});

/// Holds the latest CompatibilityVerdict the app is acting on. Always exposes
/// a non-null verdict — failures collapse to `CompatibilityVerdict.compatible`
/// so a backend hiccup never locks the user out.
class CompatibilityController extends StateNotifier<CompatibilityVerdict> {
  CompatibilityController(this._ref)
      : super(CompatibilityVerdict.compatible) {
    _bootstrap();
    _refreshTimer = Timer.periodic(_kRefreshInterval, (_) {
      // Fire-and-forget; refresh failures are non-fatal.
      unawaited(refresh());
    });
  }

  final Ref _ref;
  Timer? _refreshTimer;
  bool _disposed = false;

  Future<void> _bootstrap() async {
    await refresh();
  }

  /// Re-fetches the verdict. Safe to call any time; failures are swallowed
  /// and the previous verdict is retained.
  Future<void> refresh() async {
    if (_disposed) return;
    try {
      final repo = _ref.read(compatibilityRepositoryProvider);
      final next = await repo.fetch();
      if (_disposed) return;
      state = next;
    } catch (_) {
      // Intentional: keep the last-known verdict (or the compatible default).
      // A network error must never escalate to blocking the user.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }
}

final compatibilityControllerProvider =
    StateNotifierProvider<CompatibilityController, CompatibilityVerdict>((ref) {
  return CompatibilityController(ref);
});
