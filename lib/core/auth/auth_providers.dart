import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical TokenStore used across the app.
/// Must be Listenable (ChangeNotifier) because go_router uses it as refreshListenable.
///
/// Web note:
/// - Refresh token is HttpOnly cookie (not accessible in Dart), so we never store refreshToken on web.
/// - To avoid stale-token flicker, we also do not persist accessToken on web.
class TokenStore extends ChangeNotifier {
  static const _kAccess = 'aura_access_token';
  static const _kRefresh = 'aura_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  bool _isLoaded = false;
  final Completer<void> _loadedCompleter = Completer<void>();

  String? get accessToken => _accessToken;

  /// On web this will typically remain null (cookie-based refresh).
  String? get refreshToken => _refreshToken;

  bool get isLoaded => _isLoaded;

  /// IMPORTANT: only trust authed after load().
  bool get isAuthed =>
      _isLoaded && (_accessToken != null && _accessToken!.trim().isNotEmpty);

  /// Called on app boot.
  Future<void> load() async {
    if (_isLoaded) {
      if (!_loadedCompleter.isCompleted) _loadedCompleter.complete();
      return;
    }

    if (kIsWeb) {
      // Web: do not restore from storage.
      // Session restoration should happen via /auth/refresh HttpOnly cookie.
      _accessToken = null;
      _refreshToken = null;
      _isLoaded = true;
      if (!_loadedCompleter.isCompleted) _loadedCompleter.complete();
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);

    _isLoaded = true;
    if (!_loadedCompleter.isCompleted) _loadedCompleter.complete();
    notifyListeners();
  }

  Future<void> waitUntilLoaded() async {
    if (_isLoaded) return;
    await _loadedCompleter.future;
  }

  /// Compatibility method used across the app.
  ///
  /// Web:
  /// - access token is stored in memory only (not persisted)
  /// - refresh token is never stored (cookie-based)
  ///
  /// Non-web:
  /// - both access/refresh are persisted to SharedPreferences
  Future<void> setSession({
    String? accessToken,
    String? refreshToken,
  }) async {
    _accessToken = (accessToken?.trim().isEmpty ?? true) ? null : accessToken!.trim();

    if (kIsWeb) {
      _refreshToken = null;
      notifyListeners();
      return;
    }

    _refreshToken = (refreshToken?.trim().isEmpty ?? true) ? null : refreshToken!.trim();

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

  Future<void> clear() async => clearTokens();

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;

    if (kIsWeb) {
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);

    notifyListeners();
  }
}

final tokenStoreProvider = ChangeNotifierProvider<TokenStore>((ref) {
  final store = TokenStore();

  // Fire and forget boot load.
  // router/session providers will treat "not loaded" as AuthStatus.loading.
  unawaited(store.load());

  return store;
});