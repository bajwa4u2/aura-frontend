import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore extends ChangeNotifier {
  static const _kAccess = 'aura_access_token';
  static const _kRefresh = 'aura_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  bool _loaded = false;
  bool _loading = false;

  // Allows other layers (Dio, routing) to wait until load() completes.
  final Completer<void> _loadCompleter = Completer<void>();

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get isLoaded => _loaded;

  bool get isAuthed => (_accessToken != null && _accessToken!.trim().isNotEmpty);

  Future<void> waitUntilLoaded() => _loadCompleter.future;

  /// Safe to call multiple times.
  /// Critical rule: load() must NEVER overwrite an already-set in-memory token.
  Future<void> load() async {
    if (_loaded) return;
    if (_loading) return waitUntilLoaded();

    _loading = true;

    try {
      // If we already have a token in memory (e.g., login just happened),
      // do NOT overwrite it from prefs. Just mark loaded.
      final alreadyHaveToken =
          _accessToken != null && _accessToken!.trim().isNotEmpty;

      if (!alreadyHaveToken) {
        final prefs = await SharedPreferences.getInstance();
        _accessToken = prefs.getString(_kAccess);
        _refreshToken = prefs.getString(_kRefresh);
      }
    } catch (_) {
      // Storage failed. Keep whatever is in memory.
    } finally {
      _loaded = true;
      _loading = false;
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      notifyListeners();
    }
  }

  /// Canonical method: set tokens and persist.
  /// For cookie-refresh mode, refreshToken can be null.
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken.trim();
    _refreshToken = refreshToken?.trim();

    // Once tokens are set, we consider the store loaded.
    if (!_loaded) {
      _loaded = true;
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_accessToken != null && _accessToken!.isNotEmpty) {
        await prefs.setString(_kAccess, _accessToken!);
      } else {
        await prefs.remove(_kAccess);
      }

      // If refreshToken is null/empty (cookie mode), remove stale stored refresh.
      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        await prefs.setString(_kRefresh, _refreshToken!);
      } else {
        await prefs.remove(_kRefresh);
      }
    } catch (_) {
      // Ignore storage write failures; runtime tokens still exist in memory.
    }

    notifyListeners();
  }

  // Backward-compatible aliases
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) {
    return setTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> persistTokens({
    required String accessToken,
    String? refreshToken,
  }) {
    return setTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> setSession({
    required String accessToken,
    String? refreshToken,
  }) {
    return setTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccess);
      await prefs.remove(_kRefresh);
    } catch (_) {}

    notifyListeners();
  }
}