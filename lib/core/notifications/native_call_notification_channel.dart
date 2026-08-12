import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';

/// Cancels any active native call-ringing notification (Android's
/// `aura_calls` channel). That channel uses a genuine ringtone-style sound
/// attribute (USAGE_NOTIFICATION_RINGTONE), which Android keeps sounding
/// until the notification is explicitly cancelled — not a one-shot alert.
/// Nothing else in the app does this (no `flutter_local_notifications`, no
/// custom `FirebaseMessagingService`), so without this call the ring can
/// keep going well after the user has already tapped the notification or
/// accepted/declined the call from within the app.
///
/// Android-only; a safe no-op everywhere else (`kIsWeb` checked first —
/// `Platform.*` throws on web).
Future<void> cancelNativeCallNotifications() async {
  if (kIsWeb) {
    debugPrint('[native-notifications] skipped: web');
    return;
  }
  if (!Platform.isAndroid) {
    debugPrint('[native-notifications] skipped: not Android');
    return;
  }
  debugPrint('[native-notifications] invoking cancelCallNotifications');
  try {
    final result = await const MethodChannel(
      'org.auraplatform.app/notifications',
    ).invokeMethod<int>('cancelCallNotifications');
    debugPrint('[native-notifications] cancelCallNotifications ok, cancelledCount=$result');
  } catch (error) {
    debugPrint('[native-notifications] cancelCallNotifications failed: $error');
  }
}
