import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_bootstrap.dart';
import '../../core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';
import 'data/feed_repository.dart';
import 'domain/post.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FeedRepository(dio);
});

/// Compatibility provider for screens that expect AsyncValue + .when(...)
/// Returns the initial list only (simple, stable for web build).
final feedProvider = FutureProvider<List<Post>>((ref) async {
  await ref.watch(sessionBootstrapProvider.future);
  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authed) return [];

  final repo = ref.watch(feedRepositoryProvider);
  final page = await repo.fetchFeed(limit: 20);
  return page.items;
});

// Rebuild (and re-fetch) whenever the authenticated user identity changes so
// a stale error state from a prior session never persists into a fresh login.
final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>((ref) {
  ref.watch(isAuthedProvider);
  final repo = ref.watch(feedRepositoryProvider);
  final authStatus = ref.watch(authStatusProvider);
  return FeedController(repo, isAuthed: authStatus == AuthStatus.authed);
});

class FeedState {
  FeedState({
    required this.items,
    required this.isLoading,
    required this.isLoadingMore,
    required this.error,
    required this.nextCursor,
  });

  final List<Post> items;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final String? nextCursor;

  factory FeedState.initial() => FeedState(
        items: const <Post>[],
        isLoading: true,
        isLoadingMore: false,
        error: null,
        nextCursor: null,
      );

  FeedState copyWith({
    List<Post>? items,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    String? nextCursor,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }
}

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._repo, {bool isAuthed = false})
      : super(FeedState.initial()) {
    if (isAuthed) loadInitial();
  }

  final FeedRepository _repo;

  List<Post> _dedupeById(List<Post> items) {
    final map = <String, Post>{};
    for (final item in items) {
      final id = item.id.trim();
      if (id.isEmpty) continue;
      map[id] = item;
    }
    return map.values.toList();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final page = await _repo.fetchFeed(limit: 20);
      state = state.copyWith(
        isLoading: false,
        items: _dedupeById(page.items),
        nextCursor: page.nextCursor,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore) return;
    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final page = await _repo.fetchFeed(limit: 20, cursor: cursor);
      final merged = _dedupeById(<Post>[
        ...state.items,
        ...page.items,
      ]);

      state = state.copyWith(
        isLoadingMore: false,
        items: merged,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }
}