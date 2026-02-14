class AppConfig {
  /// Base URL for the API (no trailing slash)
  /// Local development (Chrome / Windows)
  static const String apiBaseUrl = 'https://api.aura.bajwadynesty.us';

  /// API prefix used by NestJS
  static const String apiPrefix = '/v1';

  /// Optional: app-level flags
  static const bool enableLogging = true;
}
