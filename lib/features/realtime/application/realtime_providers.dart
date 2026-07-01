import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_bootstrap.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/client_identity/client_identity_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../data/realtime_media_service.dart';
import '../data/realtime_repository.dart';
import '../data/realtime_socket_service.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_models.dart';
import '../domain/realtime_state.dart';
import 'realtime_controller.dart';

final realtimeRepositoryProvider = Provider<RealtimeRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return RealtimeRepository(dio);
});

final realtimeSocketServiceProvider = Provider<RealtimeSocketService>((ref) {
  final service = RealtimeSocketService();
  service.updateAccessToken(ref.read(tokenStoreProvider).accessToken ?? '');
  ref.listen(tokenStoreProvider, (_, next) {
    service.updateAccessToken(next.accessToken ?? '');
  });
  ref.onDispose(service.dispose);
  return service;
});

final realtimeMediaServiceProvider = Provider<RealtimeMediaService>((ref) {
  final service = RealtimeMediaService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final realtimeControllerProvider =
    StateNotifierProvider<RealtimeController, RealtimeState>((ref) {
      final repository = ref.watch(realtimeRepositoryProvider);
      final socketService = ref.watch(realtimeSocketServiceProvider);
      final mediaService = ref.watch(realtimeMediaServiceProvider);
      final tokenStore = ref.watch(tokenStoreProvider);

      final controller = RealtimeController(
        repository,
        socketService,
        mediaService,
        tokenStore,
        () => ref.read(clientIdentityProvider.future),
      );
      ref.listen(tokenStoreProvider, (_, next) {
        socketService.updateAccessToken(next.accessToken ?? '');
      });
      return controller;
    });

final liveSessionsProvider = FutureProvider<List<RealtimeSession>>((ref) async {
  await ref.watch(sessionBootstrapProvider.future);
  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) return [];
  // Guest mode: /realtime/sessions?scope=me is member-only (401 for guests).
  if (ref.watch(isGuestSessionProvider)) return [];

  // Re-fetch whenever the local controller transitions joined→idle so the
  // header "Live" pill, the conversation ribbons, and any other surface
  // backed by this provider clear immediately on call end. The
  // `realtimeControllerProvider.select` keeps the provider from rebuilding
  // on every controller mutation; only `isJoined` toggles trigger.
  ref.watch(realtimeControllerProvider.select((s) => s.isJoined));

  final repo = ref.watch(realtimeRepositoryProvider);
  return repo.listMySessions();
});

/// Strictly filtered live sessions for the header "Live" indicator.
///
/// Rules (per product spec):
/// - Only Space or Institution surfaces — never 1:1 DM, thread, or bare room.
/// - status == ACTIVE (explicit guard; backend also guarantees this).
/// - At least 2 participants with joinState ACTIVE or JOINING.
/// - Deduplicated by id.
/// - Capped at 3 items.
const _kLiveDiscoverableTypes = {
  RealtimeSurfaceType.space,
  RealtimeSurfaceType.institution,
};

final discoverableLiveSessionsProvider = FutureProvider<List<RealtimeSession>>((
  ref,
) async {
  final all = await ref.watch(liveSessionsProvider.future);
  final seen = <String>{};
  final filtered = <RealtimeSession>[];
  for (final s in all) {
    if (!_kLiveDiscoverableTypes.contains(s.surfaceType)) continue;
    if (s.status != 'ACTIVE') continue;
    if (s.activeParticipantCount < 2) continue;
    if (s.id.isEmpty || seen.contains(s.id)) continue;
    seen.add(s.id);
    filtered.add(s);
    if (filtered.length >= 3) break;
  }
  return filtered;
});
