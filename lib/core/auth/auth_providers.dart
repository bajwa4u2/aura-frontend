import 'dart:async';
import 'dart:convert';

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
  ///
  /// Checks JWT `exp` claim so a stale token persisted from a previous boot
  /// does not poison `sessionBootstrapProvider` (which early-exits on
  /// `isAuthed`). When the persisted access token is past its exp, we report
  /// unauthed so the bootstrap refresh path runs and swaps in a live token
  /// before any protected request fires.
  bool get isAuthed {
    if (!_isLoaded) return false;
    final token = _accessToken?.trim();
    if (token == null || token.isEmpty) return false;
    return !_isJwtExpired(token);
  }

  /// True when the current session is an authenticated MEMBER — an Aura account
  /// JWT — as opposed to a meeting GUEST token (which carries `type: "guest"`).
  ///
  /// Guards a member's session from being clobbered when they open a meeting
  /// join link: a guest/booker join must never downgrade a logged-in member to
  /// a guest token. Doing so 403s their host-only actions (e.g. cancelling a
  /// meeting) with no recovery, because refresh-on-401 is deliberately skipped
  /// for guest tokens.
  bool get isMemberSession {
    if (!isAuthed) return false;
    return _jwtType(_accessToken) != 'guest';
  }

  /// Reads the `type` claim from a JWT payload (null if absent/unparseable).
  static String? _jwtType(String? jwt) {
    if (jwt == null) return null;
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final padLen = (4 - payload.length % 4) % 4;
      final json = jsonDecode(
        utf8.decode(base64Url.decode(payload + ('=' * padLen))),
      );
      if (json is! Map) return null;
      final t = json['type'];
      return t is String ? t : null;
    } catch (_) {
      return null;
    }
  }

  /// True only when token is present AND not yet expired (with 30s skew).
  /// Returns false on parse error so a malformed token cannot lock the
  /// account into a permanent "authed" state with no way to refresh.
  static bool _isJwtExpired(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return false; // not a JWT — leave to backend
      final payload = parts[1];
      // Pad base64url to a multiple of 4 before decoding.
      final padLen = (4 - payload.length % 4) % 4;
      final padded = payload + ('=' * padLen);
      final bytes = base64Url.decode(padded);
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map) return false;
      final exp = json['exp'];
      if (exp is! num) return false;
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      // 30s skew: refresh slightly before exp so a request mid-flight does
      // not land at the backend with a just-expired token.
      return DateTime.now().toUtc().isAfter(
            expiresAt.subtract(const Duration(seconds: 30)),
          );
    } catch (_) {
      return false;
    }
  }

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