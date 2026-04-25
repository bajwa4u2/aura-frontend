import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'notifications_controller.dart';
import 'notifications_repository.dart';

final notificationsRepoProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(dioProvider));
});

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  final repo = ref.watch(notificationsRepoProvider);
  return NotificationsController(ref, repo);
});

final notificationsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(notificationsControllerProvider.select((state) => state.items));
});

final notificationsUnreadCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsControllerProvider.select((state) => state.unreadCount));
});
