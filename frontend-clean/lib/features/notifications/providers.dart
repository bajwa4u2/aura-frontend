import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/net/dio_provider.dart';
import 'data/notifications_repository.dart';
import 'domain/notification_item.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationsRepository(dio);
});

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return NotificationsController(repo);
});

class NotificationsState {
  NotificationsState({
    required this.items,
    required this.loading,
    required this.error,
  });

  final List<NotificationItem> items;
  final bool loading;
  final Object? error;

  factory NotificationsState.loading() =>
      NotificationsState(items: const [], loading: true, error: null);

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? loading,
    Object? error,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._repo)
      : super(NotificationsState.loading()) {
    load();
  }

  final NotificationsRepository _repo;

  Future<void> load() async {
    state = NotificationsState.loading();
    try {
      final items = await _repo.fetchNotifications();
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> markRead(NotificationItem item) async {
    if (item.isRead) return;

    try {
      await _repo.markRead(item.id);
      state = state.copyWith(
        items: state.items
            .map((n) => n.id == item.id
                ? NotificationItem(
                    id: n.id,
                    type: n.type,
                    createdAt: n.createdAt,
                    actorHandle: n.actorHandle,
                    actorDisplayName: n.actorDisplayName,
                    postText: n.postText,
                    readAt: DateTime.now(),
                  )
                : n)
            .toList(growable: false),
      );
    } catch (_) {
      // silently ignore; read status is not critical
    }
  }
}
