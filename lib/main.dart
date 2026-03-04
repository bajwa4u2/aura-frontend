import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/aura_app.dart';
import 'core/auth/auth_providers.dart';
import 'core/auth/session_bootstrap.dart';
import 'core/auth/session_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean URLs (no #)
  setUrlStrategy(PathUrlStrategy());

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

/// Boot gate:
/// - prevents "public flash" on refresh by holding UI until auth state is settled
/// - avoids router redirect thrash while providers are still loading
class _AuraBoot extends ConsumerWidget {
  const _AuraBoot();

  bool _shouldHoldSplash({
    required AsyncValue<void> bootstrap,
    required AuthStatus authStatus,
    required AsyncValue<bool> verifiedAsync,
  }) {
    // While bootstrap is running, always hold.
    if (bootstrap.isLoading) return true;

    // If bootstrap failed, we still proceed (router can handle unauth).
    // But we don't want to deadlock on splash.
    // So: do NOT hold purely because bootstrap has error.
    // (We log error below.)

    // While auth status is still computing, hold.
    if (authStatus == AuthStatus.loading) return true;

    // If authed, wait until verified check resolves,
    // otherwise router will briefly render a public route then jump.
    if (authStatus == AuthStatus.authed) {
      if (verifiedAsync.isLoading) return true;
      // If verified provider errored, don't deadlock. Let router handle.
    }

    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(sessionBootstrapProvider);

    // These are the two that cause the visible "jump" if we let UI paint early.
    final authStatus = ref.watch(authStatusProvider);
    final verifiedAsync = ref.watch(emailVerifiedProvider);

    final hold = _shouldHoldSplash(
      bootstrap: bootstrap,
      authStatus: authStatus,
      verifiedAsync: verifiedAsync,
    );

    if (bootstrap.hasError) {
      debugPrint('sessionBootstrapProvider error: ${bootstrap.error}');
    }
    if (verifiedAsync.hasError) {
      debugPrint('emailVerifiedProvider error: ${verifiedAsync.error}');
    }

    if (hold) return const _BootSplash();

    return const AuraApp();
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