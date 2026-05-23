import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/aura_app.dart';
import 'core/auth/auth_providers.dart';
import 'core/diagnostics/runtime_trace.dart';
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

  final store = TokenStore();

  try {
    await store.load();
  } catch (e) {
    debugPrint('TokenStore.load failed: $e');
  }

  // ── Global error boundary ──────────────────────────────────────────────
  // A widget that throws during build must degrade to a calm, BOUNDED inline
  // panel — never a blank/grey screen and never an unrecoverable shell. The
  // default ErrorWidget paints an opaque grey box in release builds, which
  // is what turned a single failed widget (e.g. during a message send) into
  // a "whole app went blank, only a kill-and-relaunch recovers" report.
  //
  // With this builder the failure is CONTAINED to the widget that threw: the
  // app shell, router and navigation stay alive, so the user can move away
  // and the surface recovers on its next build. FlutterError.onError above
  // still logs the real exception + stack for diagnosis.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Make the failure visible in the debug trace so a contained error
    // is still attributable. The default FlutterError.onError above logs
    // the full stack; this trace line is the short, grep-friendly
    // companion that ties the error boundary firing to the channel
    // counter used by the rest of the runtime trace.
    RuntimeTrace.emit(
      'error.boundary',
      'widget build failed',
      data: {
        'exception': details.exceptionAsString(),
        'library': details.library ?? '',
      },
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      // LimitedBox only constrains when the parent gives unbounded space
      // (e.g. inside a Column/ListView), so this is safe both as a
      // full-screen fallback and as a small inline one.
      child: LimitedBox(
        maxWidth: 420,
        maxHeight: 240,
        child: Container(
          color: const Color(0xFF11131A),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Color(0xFF9AA4B2),
                size: 30,
              ),
              SizedBox(height: 10),
              Text(
                'This section ran into a problem.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE6E9EF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'The rest of the app is still working — go back, '
                'or reopen this screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9AA4B2), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Catch uncaught async errors at the engine boundary. This replaces an
  // earlier `runZonedGuarded` wrap which produced a Flutter "Zone mismatch"
  // warning at boot — `WidgetsFlutterBinding.ensureInitialized()` had run
  // in the root zone but `runApp` was called inside the guarded zone, so
  // zone-specific configuration was inconsistent between binding init and
  // runApp ("this will likely cause confusion and bugs", per Flutter's
  // own diagnostic). `PlatformDispatcher.onError` is the modern, zone-free
  // entry point for the same intent and is honoured by the same Flutter
  // binding that set up the framework. Returning `true` marks the error
  // as handled so it does not propagate to the platform default handler.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('[PLATFORM_ERROR] $error');
    debugPrint('[PLATFORM_ERROR] stack:\n$stack');
    return true;
  };

  runApp(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWith((ref) => store),
      ],
      child: const AuraApp(),
    ),
  );
}