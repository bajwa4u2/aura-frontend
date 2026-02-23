import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TokenStore
/// - Restores tokens from SharedPreferences on app start
/// - Persists tokens on update
/// - Allows clearing tokens (logout / auth invalid)
class TokenStore extends ChangeNotifier {
  static const _kAccess = 'aura_access_token';
  static const _kRefresh = 'aura_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  bool _loaded = false;

  // Allows other layers (Dio, routing) to wait until load() completes.
  final Completer<void> _loadCompleter = Completer<void>();

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  /// Helps UI avoid firing protected calls before tokens are loaded.
  bool get isLoaded => _loaded;

  bool get isAuthed => (_accessToken != null && _accessToken!.trim().isNotEmpty);

  /// Await this when you must not act until tokens are restored.
  Future<void> waitUntilLoaded() => _loadCompleter.future;

  /// Load tokens from SharedPreferences once.
  Future<void> load() async {
    if (_loaded) {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);

    _loaded = true;

    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    notifyListeners();
  }

  /// Set tokens in memory + persist to SharedPreferences.
  Future<void> setTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    _accessToken = (accessToken?.trim().isEmpty ?? true) ? null : accessToken;
    _refreshToken = (refreshToken?.trim().isEmpty ?? true) ? null : refreshToken;

    final prefs = await SharedPreferences.getInstance();

    if (_accessToken == null) {
      await prefs.remove(_kAccess);
    } else {
      await prefs.setString(_kAccess, _accessToken!);
    }

    if (_refreshToken == null) {
      await prefs.remove(_kRefresh);
    } else {
      await prefs.setString(_kRefresh, _refreshToken!);
    }

    notifyListeners();
  }

  /// Clear tokens from memory + storage.
  /// Used when:
  /// - refresh fails
  /// - API says token invalid
  /// - user logs out
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);

    notifyListeners();
  }
}

/// Riverpod provider used across the app (Dio, routing, auth screens).
final tokenStoreProvider = ChangeNotifierProvider<TokenStore>((ref) {
  final store = TokenStore();

  // Make sure tokens are loaded as soon as provider is first read.
  // We don't await here; callers can use waitUntilLoaded().
  store.load();

  return store;
});