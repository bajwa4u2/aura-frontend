import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/auth/presentation/auth_screen.dart';

/// APP STORE REVIEW BLOCKER — Guideline 2.1(a), 2026-09-07.
///
/// Apple, reviewing 1.4.2 (37) on an iPad Air 11-inch (M3), iPadOS 26.6.1:
///
///   "We were unable to access the app because sign in button unresponsive
///    ... to create account, after receiving verification link, still unable
///    to login and access full features"
///
/// There was no widget test over the sign-in surface at any geometry, which is
/// part of why this reached review. These assert the control is REACHABLE and
/// ENABLED at iPad sizes — visible is not the same as tappable, and a button
/// that renders perfectly while something invisible eats the tap looks exactly
/// like this report.
///
/// iPad Air 11-inch is 1180x820 logical points landscape, 820x1180 portrait.
void main() {
  Future<void> pumpAuth(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        // AuraScaffold provides no Material ancestor of its own, and neither
        // does AppShell — in production the Material comes from PublicShell's
        // Scaffold. The harness mirrors that rather than inventing a simpler
        // tree, or it would test a composition the product never renders.
        child: MaterialApp(home: Scaffold(body: AuthScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The question the reviewer's finger asked: does a tap at the centre of the
  /// Sign in button actually reach that button, or does something else take
  /// it first?
  void expectTapReachesSignIn(WidgetTester tester) {
    final button =
        find.ancestor(of: find.text('Sign in'), matching: find.byType(InkWell)).first;
    expect(
      button,
      findsOneWidget,
      reason: 'the sign-in control must exist before it can be pressed',
    );

    final target = tester.getCenter(button);
    final hits = tester.hitTestOnBinding(target);
    final reached = hits.path.any((entry) {
      final t = entry.target;
      return t is RenderBox &&
          tester.any(
            find.byWidgetPredicate((w) => false),
          ) ==
              false &&
          identical(
            t,
            tester.renderObject(button),
          );
    });

    expect(
      reached,
      isTrue,
      reason:
          'a tap at the centre of the sign-in button did not reach it — '
          'something is intercepting it (overlay, barrier, gesture detector)',
    );
  }

  group('iPad sign-in is reachable', () {
    testWidgets('landscape 1180x820 — the review device orientation', (tester) async {
      await pumpAuth(tester, const Size(1180, 820));
      expectTapReachesSignIn(tester);
    });

    testWidgets('portrait 820x1180', (tester) async {
      await pumpAuth(tester, const Size(820, 1180));
      expectTapReachesSignIn(tester);
    });

    testWidgets('the button is ENABLED on arrival, not stuck busy', (tester) async {
      // `onPressed: busy ? null : onLogin` renders a disabled button, which
      // reads to a reviewer as "unresponsive" rather than as "loading".
      await pumpAuth(tester, const Size(1180, 820));
      final button = tester.widget<InkWell>(
        find.ancestor(of: find.text('Sign in'), matching: find.byType(InkWell)).first,
      );
      expect(
        button.onTap,
        isNotNull,
        reason: 'a disabled sign-in button is indistinguishable from a broken one',
      );
    });

    testWidgets('both ways out of a failed sign-in are present', (tester) async {
      // Create account and Forgot password are the reviewer's only other
      // routes; the report says they used Create account.
      await pumpAuth(tester, const Size(1180, 820));
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Forgot password'), findsOneWidget);
    });

    testWidgets('nothing overflows at review geometry', (tester) async {
      // An overflow does not always throw, but it does move controls off the
      // edge — which is how a button becomes unreachable while still existing.
      await pumpAuth(tester, const Size(1180, 820));
      expect(tester.takeException(), isNull);
    });
  });
}
