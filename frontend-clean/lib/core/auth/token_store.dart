import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore extends ChangeNotifier {
  static const _kAccess = 'aura_access_token';
  static const _kRefresh = 'aura_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  bool _loaded = false;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  /// Helps UI avoid firing protected calls before tokens are loaded.
  bool get isLoaded => _loaded;

  bool get isAuthed => (_accessToken != null && _accessToken!.trim().isNotEmpty);

  /// Load tokens from persistent storage.
  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_kAccess);

      // Web: refresh token is assumed to be httpOnly cookie by backend.
      // But we still keep a slot for non-web where refresh may be returned.
      if (kIsWeb) {
        _refreshToken = null;
      } else {
        _refreshToken = prefs.getString(_kRefresh);
      }
    } catch (_) {
      _accessToken = null;
      _refreshToken = null;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

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

    // Web: refresh token is stored in httpOnly cookie by backend.
    if (kIsWeb) {
      _refreshToken = null;
    } else {
      if (refreshToken != null && refreshToken.trim().isNotEmpty) {
        _refreshToken = refreshToken.trim();
      }
    }

    // Persist
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_accessToken == null) {
        await prefs.remove(_kAccess);
      } else {
        await prefs.setString(_kAccess, _accessToken!);
      }

      if (!kIsWeb) {
        if (_refreshToken == null) {
          await prefs.remove(_kRefresh);
        } else {
          await prefs.setString(_kRefresh, _refreshToken!);
        }
      }
    } catch (_) {
      // Ignore persistence failures; in-memory still works.
    }

    _loaded = true;
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
    notifyListeners();
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccess);
      if (!kIsWeb) {
        await prefs.remove(_kRefresh);
      }
    } catch (_) {}

    _loaded = true;
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
