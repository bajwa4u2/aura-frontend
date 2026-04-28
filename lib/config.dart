import 'dart:core';

class AppConfig {
  const AppConfig._();

  /// API base URL (INCLUDES /v1).
  ///
  /// Set via:
  /// flutter build web --dart-define=API_BASE_URL=https://api.auraplatform.org/v1
  ///
  /// IMPORTANT:
  /// - API_BASE_URL must include /v1
  /// - Client code should call endpoints like: /auth/login, /users/me, /posts, etc.
  ///   (do NOT prefix endpoints with /v1 in code)
  static String get apiBaseUrl {
    final raw = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.auraplatform.org/v1',
    ).trim();

    var u = raw.isEmpty ? 'https://api.auraplatform.org/v1' : raw;

    // Remove trailing slashes
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }

    // Ensure /v1 is present exactly once at the end
    if (!u.endsWith('/v1')) {
      u = '$u/v1';
    }

    // Safety: collapse accidental double /v1/v1
    u = u.replaceAll(RegExp(r'(/v1)+$'), '/v1');

    return u;
  }

  /// VAPID public key for Web Push.
  ///
  /// Supply via:
  /// flutter build web --dart-define=AURA_WEB_PUSH_VAPID_PUBLIC_KEY=<base64url-key>
  ///
  /// When empty, web push is disabled: the Enable button in the Security screen
  /// is effectively inert and no subscription is created. No device registration
  /// POST is sent for web without a subscription.
  static String get vapidPublicKey => const String.fromEnvironment(
    'AURA_WEB_PUSH_VAPID_PUBLIC_KEY',
    defaultValue: '',
  ).trim();
}