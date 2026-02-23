import 'package:flutter/foundation.dart';

class AppConfig {
  // Build-time define from Docker/Railway:
  // flutter build web --dart-define=API_BASE_URL=https://api.aura.bajwadynesty.us
  static const String _rawBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.aura.bajwadynesty.us',
  );

  /// Normalized API base URL:
  /// - no trailing slash
  /// - always includes /v1
  static final String apiBaseUrl = _normalizeBase(_rawBase);

  static String _normalizeBase(String input) {
    var u = input.trim();
    if (u.isEmpty) return 'https://api.aura.bajwadynesty.us/v1';

    // remove trailing slashes
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }

    // already includes /v1
    if (u.endsWith('/v1')) return u;

    return '$u/v1';
  }

  static String describe() {
    return 'AppConfig(raw=$_rawBase, apiBaseUrl=$apiBaseUrl, '
        'kIsWeb=$kIsWeb, kReleaseMode=$kReleaseMode)';
  }
}