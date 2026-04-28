import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/aura_app.dart';
import 'core/auth/auth_providers.dart';
import 'core/utils/configure_url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent Flutter framework errors from surfacing as uncaught browser errors.
  // In production web builds the default handler re-throws, which creates noise
  // in the console. We log and continue instead.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    } else {
      debugPrint('Flutter error: ${details.exceptionAsString()}');
    }
  };

  configureUrlStrategy();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase.initializeApp failed: $e');
    }
  }

  final store = TokenStore();

  try {
    await store.load();
  } catch (e) {
    debugPrint('TokenStore.load failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWith((ref) => store),
      ],
      child: const AuraApp(),
    ),
  );
}