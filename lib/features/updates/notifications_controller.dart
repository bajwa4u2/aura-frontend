import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'notifications_repository.dart';

const Duration kNotificationsPollInterval = Duration(seconds: 120);
const Duration kNotificationsStaleAfter = Duration(seconds: 30);
const int kNotificationsPageLimit = 30;

class NotificationsState {
  const NotificationsState({
    required this.items,
    required this.nextCursor,
    required this.unreadCount,
    required this.isLoading,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.error,
    required this.lastFetchedAt,
  });

  final List<Map<String, dynamic>> items;
  final String? nextCursor;
  final int unreadCount;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final String? error;
  final DateTime? lastFetchedAt;

  factory NotificationsState.initial() {
    return const NotificationsState(
      items: <Map<String, dynamic>>[],
      nextCursor: null,
      unreadCount: 0,
      isLoading: false,
      isRefreshing: false,
      isLoadingMore: false,
      error: null,
      lastFetchedAt: null,
    );
  }

  NotificationsState copyWith({
    List<Map<String, dynamic>>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    int? unreadCount,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    DateTime? lastFetchedAt,
    bool clearLastFetchedAt = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      lastFetchedAt:
          clearLastFetchedAt ? null : (lastFetchedAt ?? this.lastFetchedAt),
    );
  }

  bool get hasLoaded => lastFetchedAt != null;
  bool get hasItems => items.isNotEmpty;
  bool get isStale {
    final updated = lastFetchedAt;
    if (updated == null) return true;
    return DateTime.now().difference(updated) >= kNotificationsStaleAfter;
  }
}

class NotificationsController extends StateNotifier<NotificationsState>
    with WidgetsBindingObserver {
  NotificationsController(this.ref, this._repo) : super(NotificationsState.initial()) {
    WidgetsBinding.instance.addObserver(this);
    _syncAuth(ref.read(isAuthedProvider));
    ref.listen<bool>(isAuthedProvider, (_, next) {
      _syncAuth(next);
    });
  }

  final Ref ref;
  final NotificationsRepository _repo;

  Timer? _pollTimer;
  bool _authed = false;
  Future<void>? _inFlight;
  Future<void>? _loadMoreInFlight;

  void _syncAuth(bool authed) {
    if (_authed == authed) return;
    _authed = authed;

    if (!authed) {
      _stopPolling();
      _repo.clearCache();
      state = NotificationsState.initial();
      return;
    }

    unawaited(refresh(force: true));
    _startPolling();
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(kNotificationsPollInterval, (_) {
      unawaited(refresh());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _inFlight = null;
    _loadMoreInFlight = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _authed) {
      unawaited(refreshIfStale());
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (!_authed) {
      return;
    }
    if (_inFlight != null) {
      if (kDebugMode) {
        debugPrint('Notifications refresh skipped: request already in flight.');
      }
      return _inFlight!;
    }

    final future = _refreshInternal(force: force);
    _inFlight = future;
    try {
      await future;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  Future<void> refreshIfStale() async {
    if (!_authed || !state.isStale) return;
    await refresh(force: true);
  }

  Future<void> loadMore() async {
    if (!_authed) return;
    if (_loadMoreInFlight != null || _inFlight != null) {
      if (kDebugMode) {
        debugPrint('Notifications load-more skipped: request already in flight.');
      }
      return;
    }

    final cursor = state.nextCursor?.trim() ?? '';
    if (cursor.isEmpty) return;

    final future = _loadMoreInternal(cursor);
    _loadMoreInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_loadMoreInFlight, future)) {
        _loadMoreInFlight = null;
      }
    }
  }

  Future<void> markRead(String id) async {
    if (!_authed) return;
    await _repo.markRead(id);
    await refresh(force: true);
  }

  Future<void> markAllRead() async {
    if (!_authed) return;
    await _repo.markAllRead();
    await refresh(force: true);
  }

  Future<void> _refreshInternal({required bool force}) async {
    if (!mounted) return;
    state = state.copyWith(
      isLoading: !state.hasLoaded,
      isRefreshing: state.hasLoaded,
      clearError: true,
    );

    try {
      final page = await _repo.page(
        limit: kNotificationsPageLimit,
        forceRefresh: force,
      );
      final unreadCount = await _repo.unreadCount(forceRefresh: force);
      if (!mounted) return;
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        unreadCount: unreadCount,
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        lastFetchedAt: DateTime.now(),
        clearError: true,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        await ref.read(tokenStoreProvider).clearTokens();
        _stopPolling();
        _repo.clearCache();
        if (!mounted) return;
        state = NotificationsState.initial();
        return;
      }

      // 429 — rate-limited. Keep existing state and existing data visible.
      // The Dio interceptor already records the backoff window; the next
      // poll cycle will skip the request if still within that window.
      if (statusCode == 429) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          clearError: true,
        );
        return;
      }

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: _readApiError(error),
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: error.toString(),
      );
    }
  }

  Future<void> _loadMoreInternal(String cursor) async {
    if (!mounted) return;
    state = state.copyWith(
      isLoadingMore: true,
      clearError: true,
    );

    try {
      final page = await _repo.page(
        limit: kNotificationsPageLimit,
        cursor: cursor,
        forceRefresh: true,
      );
      final merged = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final item in [...state.items, ...page.items]) {
        final id = _stringOf(item['id']);
        if (id.isEmpty || seen.contains(id)) {
          continue;
        }
        seen.add(id);
        merged.add(item);
      }

      final unreadCount = merged.where((item) => _stringOf(item['readAt']).isEmpty).length;
      if (!mounted) return;
      state = state.copyWith(
        items: merged,
        unreadCount: unreadCount,
        nextCursor: page.nextCursor,
        isLoadingMore: false,
        lastFetchedAt: DateTime.now(),
        clearError: true,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        await ref.read(tokenStoreProvider).clearTokens();
        _stopPolling();
        _repo.clearCache();
        if (!mounted) return;
        state = NotificationsState.initial();
        return;
      }

      if (!mounted) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: _readApiError(error),
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: error.toString(),
      );
    }
  }

  String _readApiError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      final text = message?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return error.message ?? 'Could not load notifications.';
  }

  String _stringOf(dynamic value) => value?.toString().trim() ?? '';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }
}
