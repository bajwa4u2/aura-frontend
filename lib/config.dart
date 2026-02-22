import 'package:flutter/foundation.dart';

class AppConfig {
  /// API base URL (includes /v1).
  /// Example:
  /// - local:    http://localhost:3000/v1
  /// - prod:     https://api.aura.bajwadynesty.us/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.aura.bajwadynesty.us/v1',
  );

  static String describe() {
    return 'AppConfig(apiBaseUrl=$apiBaseUrl, kReleaseMode=$kReleaseMode, kIsWeb=$kIsWeb)';
  }
}