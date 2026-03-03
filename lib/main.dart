import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/aura_app.dart';
import 'core/auth/auth_providers.dart';
import 'core/auth/session_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web: remove hash (#) routing so links like
  // https://auraplatform.org/reset-password?token=...
  // land on real routes.
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
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
      child: const _AuraBoot(),
    ),
  );
}

class _AuraBoot extends ConsumerWidget {
  const _AuraBoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(sessionBootstrapProvider);

    return boot.when(
      data: (_) => const AuraApp(),
      loading: () => const _BootSplash(),
      error: (e, _) {
        debugPrint('sessionBootstrapProvider error: $e');
        return const AuraApp();
      },
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}