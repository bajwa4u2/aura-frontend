import 'package:flutter/foundation.dart';

class AppConfig {
  /// API base host (NO /v1 here).
  /// Example:
  /// - local:    http://localhost:3000
  /// - prod:     https://your-backend.up.railway.app
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static String describe() {
    return 'AppConfig(apiBaseUrl=$apiBaseUrl, kReleaseMode=$kReleaseMode, kIsWeb=$kIsWeb)';
  }
}