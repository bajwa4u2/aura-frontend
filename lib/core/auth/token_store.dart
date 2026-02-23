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

  bool get isAuthed =>
      (_accessToken != null && _accessToken!.trim().isNotEmpty);

  /// Await this when you must not act until tokens are restored.
  Future<void> waitUntilLoaded() => _loadCompleter.future;

  Future<void> load() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);

    _loaded = true;
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();

    notifyListeners();
  }

  /// Canonical API used by most of the codebase.
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await setTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  /// Canonical API used by most of the codebase.
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    _accessToken = accessToken.trim().isEmpty ? null : accessToken.trim();
    _refreshToken = (refreshToken == null || refreshToken.trim().isEmpty)
        ? null
        : refreshToken.trim();

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

    _loaded = true;
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();

    notifyListeners();
  }

  /// Compatibility API (some screens call this).
  /// Keep it so we don’t break older UI paths.
  Future<void> setSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    await setTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = null;
    _refreshToken = null;

    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);

    _loaded = true;
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();

    notifyListeners();
  }
}