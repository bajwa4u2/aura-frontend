import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../data/realtime_repository.dart';
import '../data/realtime_socket_service.dart';
import '../domain/realtime_state.dart';
import 'realtime_controller.dart';

final realtimeRepositoryProvider = Provider<RealtimeRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return RealtimeRepository(dio);
});

final realtimeSocketServiceProvider = Provider<RealtimeSocketService>((ref) {
  final service = RealtimeSocketService();
  ref.onDispose(service.dispose);
  return service;
});

final realtimeControllerProvider =
    StateNotifierProvider<RealtimeController, RealtimeState>((ref) {
  final repository = ref.watch(realtimeRepositoryProvider);
  final socketService = ref.watch(realtimeSocketServiceProvider);
  final tokenStore = ref.watch(tokenStoreProvider);

  return RealtimeController(
    repository,
    socketService,
    tokenStore,
  );
});
