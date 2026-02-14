import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/aura_app.dart';
import 'core/auth/session_providers.dart';
import 'core/auth/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = TokenStore();

  try {
    await store.load();
  } catch (e) {
    // Never block app startup on token loading.
    // TokenStore is safe to start empty.
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
