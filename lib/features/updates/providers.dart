import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';
import 'notifications_repository.dart';

const int kNotificationsPageLimit = 30;

final notificationsRepoProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(dioProvider));
});

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return const <Map<String, dynamic>>[];

  final repo = ref.read(notificationsRepoProvider);
  return repo.list(limit: kNotificationsPageLimit);
});

final notificationsUnreadCountProvider = FutureProvider<int>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return 0;
  final repo = ref.read(notificationsRepoProvider);
  return repo.unreadCount();
});
