import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';
import 'notifications_repository.dart';

final notificationsRepoProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(dioProvider));
});

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return const <Map<String, dynamic>>[];

  final repo = ref.read(notificationsRepoProvider);
  return repo.list(limit: 24);
});
