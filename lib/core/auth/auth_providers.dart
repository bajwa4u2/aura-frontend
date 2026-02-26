import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canonical TokenStore used across the app.
/// Must be Listenable (ChangeNotifier) because go_router uses it as refreshListenable.
///
/// Web note:
/// - Refresh token is HttpOnly cookie (not accessible in Dart), so we never store refreshToken on web.
class TokenStore extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;

  bool _isLoaded = false;
  final Completer<void> _loadedCompleter = Completer<void>();

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get isLoaded => _isLoaded;

  bool get isAuthed => (_accessToken != null && _accessToken!.trim().isNotEmpty);

  /// Called on app boot. Later you can load from secure storage.
  Future<void> load() async {
    if (_isLoaded) return;
    _isLoaded = true;

    if (!_loadedCompleter.isCompleted) {
      _loadedCompleter.complete();
    }

    notifyListeners();
  }

  Future<void> waitUntilLoaded() async {
    if (_isLoaded) return;
    await _loadedCompleter.future;
  }

  Future<void> setSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken.trim();

    if (kIsWeb) {
      // Web refresh token lives in HttpOnly cookie; never store it here.
      _refreshToken = null;
    } else {
      _refreshToken = refreshToken?.trim();
      if (_refreshToken != null && _refreshToken!.isEmpty) _refreshToken = null;
    }

    notifyListeners();
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    notifyListeners();
  }

  Future<void> clearTokens() => clear();
}

final tokenStoreProvider = ChangeNotifierProvider<TokenStore>((ref) {
  final store = TokenStore();
  // Fire and forget boot load.
  // router/session providers will treat "not loaded" as AuthStatus.loading.
  unawaited(store.load());
  return store;
});