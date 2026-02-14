class TokenStore {
  String? accessToken;
  String? refreshToken;
  String? userId;

  TokenStore();

  Future<void> load() async {
    // No-op on IO in this minimal version.
    // If you later add SharedPreferences/Hive, implement here.
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    if (userId != null && userId.isNotEmpty) this.userId = userId;
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
  }
}
