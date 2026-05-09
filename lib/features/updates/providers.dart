import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'app_notification.dart';
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

/// Typed view over [notificationsControllerProvider]'s items. Notifications
/// screen consumes this; other surfaces (bell, activity tab) can keep
/// reading the raw maps. A single canonical mapper means the typed and
/// raw consumers can never diverge on parsing — see consolidation PR for
/// the prior dual-repository drift.
///
/// Per-row `fromJson` failures are logged (so a real DTO drift is
/// noticed) but never collapse the list.
final appNotificationsListProvider = Provider<List<AppNotification>>((ref) {
  final raw = ref.watch(
    notificationsControllerProvider.select((state) => state.items),
  );
  final out = <AppNotification>[];
  for (final entry in raw) {
    try {
      out.add(AppNotification.fromJson(entry));
    } catch (error, stack) {
      // ignore: avoid_print
      print('notifications.parse_failed id=${entry['id']} err=$error\n$stack');
    }
  }
  return out;
});
