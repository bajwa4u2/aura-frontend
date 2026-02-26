import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal token store used by Dio interceptor + auth flows.
/// - Web: refresh token is HttpOnly cookie, so we DO NOT store refreshToken.
/// - Mobile/desktop: refresh token may be stored in memory (and later persisted if needed).
class TokenStore {
  String? _accessToken;
  String? _refreshToken;

  final Completer<void> _loaded = Completer<void>();

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  /// In your project, this can later load from secure storage.
  /// For now: "loaded" immediately so requests can proceed.
  Future<void> init() async {
    if (!_loaded.isCompleted) _loaded.complete();
  }

  Future<void> waitUntilLoaded() async {
    await _loaded.future;
  }

  Future<void> setSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken;

    // Web must not store refresh token (HttpOnly cookie).
    if (kIsWeb) {
      _refreshToken = null;
    } else {
      _refreshToken = refreshToken;
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  final store = TokenStore();
  // Fire and forget; Dio will still waitUntilLoaded() safely.
  store.init();
  return store;
});