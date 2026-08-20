import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/release_governance/compatibility_models.dart';
import 'package:aura/core/release_governance/compatibility_provider.dart';
import 'package:aura/core/release_governance/compatibility_repository.dart';
import 'package:aura/core/release_governance/update_gate.dart';
import 'package:aura/router.dart';

/// THE MAINTENANCE SCREEN MUST ACTUALLY RENDER.
///
/// Found in production on 2026-08-20, the first time maintenance was ever
/// switched on: gated clients got
///
///   GoError: There is no GoRouterState above the current context.
///
/// instead of the maintenance message. `UpdateGate` is mounted in
/// `MaterialApp.router`'s `builder` — deliberately, so the blocking screens
/// have Material and MediaQuery ancestors — which puts it ABOVE the route tree.
/// `GoRouterState.of(context)` only resolves under a `RouteBase.builder`.
///
/// The read sat on the maintenance branch alone, so every other verdict
/// exercised the widget without ever touching it and the gate looked healthy
/// for as long as nothing was gated.
///
/// This test mounts the gate the way the app mounts it. A version that put the
/// gate inside a route would pass while production burned.
void main() {
  CompatibilityVerdict verdict(CompatibilityStatus status, {String? message}) {
    return CompatibilityVerdict(
      status: status,
      action: status == CompatibilityStatus.maintenance
          ? CompatibilityAction.showMaintenance
          : CompatibilityAction.none,
      message: message,
      minSupportedVersion: null,
      recommendedVersion: null,
      latestVersion: null,
      storeUrl: null,
      policyMatched: status != CompatibilityStatus.compatible,
      evaluatedDistribution: 'ios',
      evaluatedChannel: 'production',
    );
  }

  /// Mirrors `aura_app.dart`: the gate lives in the router's `builder`, above
  /// every route.
  Widget appWithGate(CompatibilityVerdict v) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('member surface')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        routerProvider.overrideWithValue(router),
        // Drive the real controller through a stubbed fetch rather than
        // substituting the controller: the thing under test is what the widget
        // does with a maintenance verdict, and the real controller is how it
        // gets one.
        compatibilityRepositoryProvider.overrideWithValue(_StubRepository(v)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            UpdateGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }

  testWidgets('maintenance renders the message, not a GoError', (tester) async {
    const copy =
        'Aura is being upgraded. The updated experience is scheduled for '
        'August 22. Please return once the upgrade is available.';

    await tester.pumpWidget(
      appWithGate(verdict(CompatibilityStatus.maintenance, message: copy)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('upgraded'), findsWidgets);
    expect(find.text('member surface'), findsNothing);

    // Dispose the scope so the controller's periodic refresh timer is
    // cancelled and the test does not fail on a pending timer.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a compatible verdict still shows the app', (tester) async {
    await tester.pumpWidget(appWithGate(verdict(CompatibilityStatus.compatible)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('member surface'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _StubRepository implements CompatibilityRepository {
  _StubRepository(this._verdict);

  final CompatibilityVerdict _verdict;

  @override
  Future<CompatibilityVerdict> fetch() async => _verdict;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
