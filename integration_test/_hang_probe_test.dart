import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/features/meetings/application/meetings_provider.dart';
import 'package:aura/router.dart';

/// Bootstrap-hang probe: cold-enter a meeting record and watch the provider.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('does meetingProvider ever resolve?', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    final router = container.read(routerProvider);
    router.go('/meetings/cmspjltbt02hspb0ctaizevcs');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));

    const id = 'cmspjltbt02hspb0ctaizevcs';
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
      final s = container.read(meetingProvider(id));
      // ignore: avoid_print
      print('[probe] t=${i + 1}s loading=${s.isLoading} '
          'hasValue=${s.hasValue} hasError=${s.hasError} '
          'err=${s.hasError ? s.error.runtimeType : "-"}');
      if (!s.isLoading) break;
    }
  });
}
