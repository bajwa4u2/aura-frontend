import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Call once at startup (or first provider read). Safe to call multiple times.
  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_kAccess);
      _refreshToken = prefs.getString(_kRefresh);
    } catch (_) {
      // If storage fails, treat as logged out.
      _accessToken = null;
      _refreshToken = null;
    } finally {
      _loaded = true;
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      notifyListeners();
    }
  }

  /// Canonical method: set tokens and persist.
  /// For Mode B (HttpOnly refresh cookie), refreshToken can be null.
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken.trim();
    _refreshToken = refreshToken?.trim();

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_accessToken != null && _accessToken!.isNotEmpty) {
        await prefs.setString(_kAccess, _accessToken!);
      } else {
        await prefs.remove(_kAccess);
      }

      // If refreshToken is null/empty (cookie mode), remove any stale stored refresh.
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

  /// Backward-compatible alias (some files may call this name).
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) {
    return setTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  /// Backward-compatible alias (some files may call this name).
  Future<void> persistTokens({
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