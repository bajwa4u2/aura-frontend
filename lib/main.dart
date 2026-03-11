import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/aura_app.dart';
import 'core/auth/auth_providers.dart';
import 'core/utils/configure_url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  configureUrlStrategy();

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