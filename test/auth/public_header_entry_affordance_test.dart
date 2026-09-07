import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/app/shell/public_shell.dart';
import 'package:aura/core/auth/session_providers.dart';

/// A VISITOR MUST ALWAYS HAVE A WAY IN.
///
/// The public header rendered NEITHER "Sign in" NOR "Join" while auth was
/// bootstrapping. The intent was right — a signed-in person should not see
/// "Join | Sign in" flash past on reload — but it was unbounded: the bootstrap
/// allows 15s to connect and 30s to receive, and for all of that time a
/// signed-out visitor had no entry affordance at all.
///
/// On a fresh install over a slow or proxied network, which is exactly an App
/// Review situation, the product cannot be entered. Apple reported 1.4.2 (37)
/// under Guideline 2.1(a) with "sign in button unresponsive".
///
/// APPLE_ROOT_CAUSE = NOT YET PROVEN. This is guarded because it is a defect,
/// not because it is established as the cause of that rejection.
void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required AuthStatus status,
  }) async {
    tester.view
      ..physicalSize = const Size(1180, 820) // iPad Air 11-inch, landscape
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // PublicShell reads GoRouterState, so it must be mounted the way the
    // product mounts it — under a ShellRoute — rather than in a bare tree.
    final router = GoRouter(
      initialLocation: '/public',
      routes: [
        ShellRoute(
          builder: (_, __, child) => PublicShell(child: child),
          routes: [
            GoRoute(path: '/public', builder: (_, __) => const SizedBox.shrink()),
            GoRoute(path: '/login', builder: (_, __) => const SizedBox.shrink()),
            GoRoute(path: '/register', builder: (_, __) => const SizedBox.shrink()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStatusProvider.overrideWithValue(status),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  group('the public header always offers a way in', () {
    testWidgets('SHOWS NOTHING briefly while auth resolves — anti-flash preserved',
        (tester) async {
      await pumpHeader(tester, status: AuthStatus.loading);
      // Inside the grace: a signed-in person must not see the signed-out CTAs.
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Join'), findsNothing);
    });

    testWidgets('OFFERS SIGN IN once the grace elapses, even if auth never resolves',
        (tester) async {
      // The defect: a slow network left this state indefinitely, and the
      // visitor had no way into the product.
      await pumpHeader(tester, status: AuthStatus.loading);
      await tester.pump(_PublicHeaderGrace.window + const Duration(milliseconds: 50));

      expect(
        find.text('Sign in'),
        findsOneWidget,
        reason: 'a visitor must never be left with no entry affordance',
      );
      expect(find.text('Join'), findsOneWidget);
    });

    testWidgets('the grace is bounded, not tied to the network timeout', (tester) async {
      // The bootstrap allows 15s connect / 30s receive. The header must not.
      expect(
        _PublicHeaderGrace.window,
        lessThan(const Duration(seconds: 3)),
        reason: 'an anti-flash window measured in seconds is a dead end',
      );
    });

    testWidgets('a resolved signed-out visitor sees the way in immediately',
        (tester) async {
      await pumpHeader(tester, status: AuthStatus.unauthed);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
    });
  });
}

/// Reads the production constant, so the bound cannot drift in one place and
/// be asserted in another.
class _PublicHeaderGrace {
  static Duration get window => publicHeaderAuthGraceWindow;
}
