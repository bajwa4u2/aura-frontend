import 'dart:core';

class AppConfig {
  const AppConfig._();

  /// API base URL (NO /v1 here).
  ///
  /// Set via:
  /// flutter build web --dart-define=API_BASE_URL=https://aura.auraplatform.org
  ///
  /// IMPORTANT:
  /// - Do not include /v1 in API_BASE_URL.
  /// - Client code may call endpoints like: /v1/users/me, /v1/posts, etc.
  static String get apiBaseUrl {
    final raw = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://aura.auraplatform.org',
    ).trim();

    if (raw.isEmpty) return 'https://aura.auraplatform.org';

    var u = raw;

    // Strip trailing slashes
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }

    // If someone mistakenly provides .../v1, strip it to prevent /v1/v1.
    if (u.endsWith('/v1')) {
      u = u.substring(0, u.length - 3);
      while (u.endsWith('/')) {
        u = u.substring(0, u.length - 1);
      }
    }

    return u;
  }
}