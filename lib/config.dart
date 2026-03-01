import 'dart:core';

class AppConfig {
  const AppConfig._();

  /// API base URL (NO /v1 here).
  ///
  /// Set via:
  /// flutter build web --dart-define=API_BASE_URL=https://api.auraplatform.org
  ///
  /// IMPORTANT:
  /// - Do not include /v1 in API_BASE_URL.
  /// - Client code calls endpoints like: /v1/users/me, /v1/posts, etc.
  static String get apiBaseUrl {
    final raw = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.auraplatform.org',
    ).trim();

    if (raw.isEmpty) return 'https://api.auraplatform.org';

    var u = raw;

    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }

    if (u.endsWith('/v1')) {
      u = u.substring(0, u.length - 3);
      while (u.endsWith('/')) {
        u = u.substring(0, u.length - 1);
      }
    }

    return u;
  }
}