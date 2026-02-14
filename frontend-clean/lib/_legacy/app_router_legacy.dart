import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'state/app_state.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AuraApp(),
    ),
  );
}

class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return AppStateProvider(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'AURA',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
        ),
        routerConfig: router,
      ),
    );
  }
}
