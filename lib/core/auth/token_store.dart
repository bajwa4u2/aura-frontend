import 'dart:async';
import 'dart:convert';

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
  Future<void> waitUntilLoaded() {
    if (_loaded && !_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    return _loadCompleter.future;
  }

  /// Load tokens from persistent storage.
  Future<void> load() async {
    if (_loaded) {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_kAccess);

      // IMPORTANT:
      // We currently persist refreshToken on web as well because our backend
      // returns refreshToken in JSON (not as httpOnly cookie).
      // This enables session refresh and prevents 401 loops after token expiry.
      _refreshToken = prefs.getString(_kRefresh);
    } catch (_) {
      _accessToken = null;
      _refreshToken = null;
    } finally {
      _loaded = true;
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      notifyListeners();
    }
  }

  /// Derive userId from the JWT if present.
  String? get userId {
    final token = _accessToken;
    if (token == null || token.trim().isEmpty) return null;

    final payload = _tryDecodeJwtPayload(token);
    if (payload == null) return null;

    final sub = payload['sub'];
    if (sub != null && sub.toString().trim().isNotEmpty) return sub.toString();

    final uid = payload['userId'];
    if (uid != null && uid.toString().trim().isNotEmpty) return uid.toString();

    return null;
  }

  /// Back-compat alias used by UI screens.
  /// `userId` is accepted for compatibility but not stored (we derive it from JWT).
  Future<void> setSession({
    String? userId,
    required String accessToken,
    String? refreshToken,
  }) async {
    await setTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> setTokens({required String accessToken, String? refreshToken}) async {
    _accessToken = accessToken.trim().isEmpty ? null : accessToken.trim();

    // Store refresh token on ALL platforms for now.
    // (If we later move to httpOnly cookie on web, we can revisit this.)
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      _refreshToken = refreshToken.trim();
    }

    try {
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
    } catch (_) {
      // Ignore persistence failures; in-memory still works.
    }

    _loaded = true;
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    notifyListeners();
  }

  Future<void> setAccessToken(String accessToken) async {
    _accessToken = accessToken.trim().isEmpty ? null : accessToken.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken == null) {
        await prefs.remove(_kAccess);
      } else {
        await prefs.setString(_kAccess, _accessToken!);
      }
    } catch (_) {}

    _loaded = true;
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    notifyListeners();
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccess);
      await prefs.remove(_kRefresh);
    } catch (_) {}

    _loaded = true;
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    notifyListeners();
  }

  Map<String, dynamic>? _tryDecodeJwtPayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return null;

      final payloadPart = parts[1];
      final normalized = base64Url.normalize(payloadPart);
      final bytes = base64Url.decode(normalized);
      final jsonStr = utf8.decode(bytes);
      final obj = json.decode(jsonStr);

      if (obj is Map) return Map<String, dynamic>.from(obj);
      return null;
    } catch (_) {
      return null;
    }
  }
}