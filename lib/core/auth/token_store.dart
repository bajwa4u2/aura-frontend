import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TokenStore
/// - Restores tokens from SharedPreferences on app start (non-web)
/// - Persists tokens on update (non-web)
/// - Provides compatibility methods used across the app:
///   - setSession(accessToken, refreshToken)
///   - clearTokens()
///   - clear()
///
/// Web note:
/// Aura web uses cookie-based refresh (HttpOnly). Persisting refresh tokens in JS
/// storage is both insecure and can cause auth-state instability.
/// We therefore do NOT persist refreshToken on web.
/// Access token persistence on web is optional; to reduce stale-token flicker we also
/// avoid persisting accessToken by default.
class TokenStore extends ChangeNotifier {
  static const _kAccess = 'aura_access_token';
  static const _kRefresh = 'aura_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  bool _loaded = false;

  // Allows other layers (Dio, routing) to wait until load() completes.
  final Completer<void> _loadCompleter = Completer<void>();

  String? get accessToken => _accessToken;

  /// On web this will typically remain null (cookie-based refresh).
  String? get refreshToken => _refreshToken;

  /// Helps UI avoid firing protected calls before tokens are loaded.
  bool get isLoaded => _loaded;

  /// IMPORTANT:
  /// Only treat user as authed after tokens are loaded.
  bool get isAuthed =>
      _loaded && (_accessToken != null && _accessToken!.trim().isNotEmpty);

  /// Await this when you must not act until tokens are restored.
  Future<void> waitUntilLoaded() => _loadCompleter.future;

  /// Load tokens from SharedPreferences once.
  ///
  /// Web behavior:
  /// - Do not restore refresh token from storage (cookie-based).
  /// - Do not restore access token from storage (prevents stale token thrash).
  Future<void> load() async {
    if (_loaded) {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      return;
    }

    if (kIsWeb) {
      // Web: treat storage as empty. Session restore should happen via /auth/refresh cookie.
      _accessToken = null;
      _refreshToken = null;
      _loaded = true;
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);

    _loaded = true;

    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    notifyListeners();
  }

  /// Set tokens in memory + persist to SharedPreferences (non-web).
  ///
  /// Web: store in memory only (no persistence).
  Future<void> setTokens({
    String? accessToken,
    String? refreshToken,
  }) async {
    _accessToken = (accessToken?.trim().isEmpty ?? true) ? null : accessToken;
    _refreshToken = (refreshToken?.trim().isEmpty ?? true) ? null : refreshToken;

    if (kIsWeb) {
      // Web: do not persist tokens.
      // Refresh token is cookie-based; access token persistence causes stale-token flicker.
      notifyListeners();
      return;
    }

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

  /// Compatibility alias expected by existing code.
  Future<void> setSession({
    String? accessToken,
    String? refreshToken,
  }) async {
    await setTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  /// Clear tokens from memory + storage.
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;

    if (kIsWeb) {
      // Web: just clear memory. Cookie is managed server-side.
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);

    notifyListeners();
  }

  /// Compatibility alias expected by existing code.
  Future<void> clear() async {
    await clearTokens();
  }
}