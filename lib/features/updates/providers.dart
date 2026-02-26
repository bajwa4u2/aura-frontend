import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'package:aura/core/auth/session_providers.dart';

import 'updates_repository.dart';

final notificationsRepoProvider = Provider<UpdatesRepository>((ref) {
  return UpdatesRepository(ref.watch(dioProvider));
});

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return const <Map<String, dynamic>>[];

  final repo = ref.watch(notificationsRepoProvider);
  return repo.listUpdates(limit: 24);
});