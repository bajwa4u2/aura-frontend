import 'dart:convert';
import 'dart:html' as html;

class TokenStore {
  static const _kKey = 'aura_tokens_v1';

  String? accessToken;
  String? refreshToken;
  String? userId;

  TokenStore();

  Future<void> load() async {
    try {
      final raw = html.window.localStorage[_kKey];
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final map = Map<String, dynamic>.from(decoded as Map);
      accessToken = (map['accessToken'] as String?)?.trim();
      refreshToken = (map['refreshToken'] as String?)?.trim();
      userId = (map['userId'] as String?)?.trim();
    } catch (_) {
      // ignore
    }
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    if (userId != null && userId.isNotEmpty) this.userId = userId;
    await _persist();
  }

  /// Backward-compatible wrapper used by older screens.
  Future<void> setSession({
    required String userId,
    required String accessToken,
    required String refreshToken,
  }) async {
    await setTokens(accessToken: accessToken, refreshToken: refreshToken, userId: userId);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    userId = null;
    await _persist(clear: true);
  }

  Future<void> _persist({bool clear = false}) async {
    try {
      if (clear) {
        html.window.localStorage.remove(_kKey);
        return;
      }

      final payload = <String, dynamic>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'userId': userId,
      };

      html.window.localStorage[_kKey] = jsonEncode(payload);
    } catch (_) {
      // ignore
    }
  }
}
