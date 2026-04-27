import 'web_push_types.dart';

export 'web_push_types.dart';

/// Stub used on non-web platforms. All methods return unavailable/null.
class WebPushService {
  const WebPushService._();

  static bool get isSupported => false;

  static String get permission => 'unavailable';

  static Future<WebPushResult?> getExistingSubscription() async => null;

  static Future<String> requestPermission() async => 'denied';

  static Future<WebPushResult?> subscribe(String vapidPublicKey) async => null;
}
