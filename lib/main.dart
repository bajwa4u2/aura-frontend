import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/aura_app.dart';
import 'core/auth/auth_providers.dart';
import 'core/diagnostics/runtime_diagnostics.dart'; // DIAGNOSTIC: REMOVE BEFORE STORE RELEASE
import 'core/utils/configure_url_strategy.dart';

// Top-level handler required by firebase_messaging for background/killed-app
// message processing. Must be annotated so the Dart tree shaker keeps it.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background/killed-app FCM messages are captured here.
  // No UI work is possible; the actual call/notification handling runs when
  // the app is foregrounded via onMessageOpenedApp or getInitialMessage.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent Flutter framework errors from surfacing as uncaught browser errors.
  // In production web builds the default handler re-throws, which creates noise
  // in the console. We log and continue instead.
  // TRACE: always print full stack so the exact crashing line is visible in
  // browser DevTools console regardless of build mode.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[FLUTTER_ERROR] ${details.exceptionAsString()}');
    debugPrint('[FLUTTER_ERROR] library: ${details.library}');
    debugPrint('[FLUTTER_ERROR] context: ${details.context}');
    debugPrint('[FLUTTER_ERROR] stack:\n${details.stack}');
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  configureUrlStrategy();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      // Request foreground presentation on iOS (badge + sound + alert).
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Firebase setup failed: $e');
    }
  }

  // DIAGNOSTIC: REMOVE BEFORE STORE RELEASE
  // Initialize the diagnostic file sink early so even bootstrap-time Dio
  // events land in the log. No-op unless --dart-define=AURA_DIAGNOSTIC=true.
  try {
    await RuntimeDiagnostics.initializeFileSink();
  } catch (e) {
    debugPrint('RuntimeDiagnostics.initializeFileSink failed: $e');
  }

  final store = TokenStore();

  try {
    await store.load();
  } catch (e) {
    debugPrint('TokenStore.load failed: $e');
  }

  // Catch async errors thrown outside of Flutter's error handling (e.g., inside
  // provider notifiers or event stream handlers). These do NOT reach
  // FlutterError.onError and would otherwise be silently swallowed in web.
  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWith((ref) => store),
          ],
          child: const AuraApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('[ZONE_ERROR] $error');
      debugPrint('[ZONE_ERROR] stack:\n$stack');
    },
  );
}