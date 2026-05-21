// Runtime validation — drives the REAL Aura app against the production
// backend (https://api.auraplatform.org/v1) with the review account, to
// catch boot crashes, login failures, routing exceptions and
// widget-build exceptions before a store release.
//
// Credentials are passed at run time and are never committed:
//
//   flutter test integration_test/runtime_validation_test.dart -d windows \
//     --dart-define=REVIEW_EMAIL=<email> --dart-define=REVIEW_PASSWORD=<pw>
//
// Scope: boot, the authentication path, authenticated shell + home
// render, and best-effort surface navigation, each guarded by no-crash
// assertions. This is NOT visual validation — layout voids, clipping
// and gesture feel are out of an automated test's reach and remain a
// human gate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/ui/aura_platform_components.dart';
import 'package:aura/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const reviewEmail = String.fromEnvironment('REVIEW_EMAIL');
  const reviewPassword = String.fromEnvironment('REVIEW_PASSWORD');

  testWidgets(
    'boot + review-account login + authenticated surfaces',
    (tester) async {
      void log(String m) => debugPrint('>>> RUNTIME_VALIDATION: $m');

      // The app runs continuous animations (live-pulse dots etc.), so
      // the widget tree never reaches a steady state — pumpAndSettle
      // would hang. Drive the clock with bounded fixed pumps instead.
      Future<void> settle([int seconds = 4]) async {
        final end = DateTime.now().add(Duration(seconds: seconds));
        while (DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      expect(reviewEmail, isNotEmpty,
          reason: 'pass --dart-define=REVIEW_EMAIL');
      expect(reviewPassword, isNotEmpty,
          reason: 'pass --dart-define=REVIEW_PASSWORD');

      // ── BOOT ──────────────────────────────────────────────────────
      app.main();
      await settle(8); // boot + first network round-trips
      expect(tester.takeException(), isNull, reason: 'app boot');
      log('boot OK — no uncaught exception');

      // ── REACH + DRIVE LOGIN ───────────────────────────────────────
      final fields = find.byType(TextField);
      if (fields.evaluate().length < 2) {
        log('login form not located after boot (${fields.evaluate().length} '
            'text fields) — cannot drive login; check manually');
      } else {
        await tester.enterText(fields.at(0), reviewEmail);
        await tester.enterText(fields.at(1), reviewPassword);
        await tester.pump(const Duration(milliseconds: 400));
        log('review credentials entered');

        final signIn = find.widgetWithText(AuraPrimaryButton, 'Sign in');
        expect(signIn, findsOneWidget, reason: 'Sign in button');
        await tester.tap(signIn);
        log('login submitted — awaiting backend');
        await settle(15);
        expect(tester.takeException(), isNull, reason: 'login round-trip');
      }

      // ── LOGIN OUTCOME ─────────────────────────────────────────────
      if (find.text('Check your email').evaluate().isNotEmpty) {
        log('OUTCOME: email-code 2FA challenge reached cleanly (no '
            'crash). An automated test cannot read the emailed code — '
            'authenticated surfaces are NOT reachable by this run.');
        log('VALIDATION RUN COMPLETE (stopped at 2FA gate)');
        return;
      }
      if (find.text('Sign-in failed').evaluate().isNotEmpty) {
        fail('login returned "Sign-in failed" — backend or '
            'review-account state must be resolved before release');
      }
      if (find.widgetWithText(AuraPrimaryButton, 'Sign in')
          .evaluate()
          .isNotEmpty) {
        log('OUTCOME: still on the login screen with no error/2FA after '
            'the round-trip — login did not complete; check manually');
        log('VALIDATION RUN COMPLETE (login inconclusive)');
        return;
      }
      log('OUTCOME: login accepted — session established.');

      // ── AUTHENTICATED SHELL + HOME ────────────────────────────────
      await settle(10); // home feed + contextual rails fetch
      expect(tester.takeException(), isNull,
          reason: 'authenticated shell + home render');
      log('authenticated shell + home rendered — no exception');

      // ── BEST-EFFORT SURFACE NAVIGATION ────────────────────────────
      // Tap navigation destinations when present; a missing target is
      // logged and skipped (route labels vary by viewport / account),
      // an exception after a tap fails the run.
      for (final label in const [
        'Notifications',
        'Announcements',
        'Explore',
        'Profile',
        'Works',
      ]) {
        final target = find.text(label);
        if (target.evaluate().isEmpty) {
          log('surface "$label" — nav target not found, skipped');
          continue;
        }
        await tester.tap(target.first, warnIfMissed: false);
        await settle(6);
        expect(tester.takeException(), isNull, reason: 'surface "$label"');
        log('surface "$label" — navigated, no exception');
      }

      log('VALIDATION RUN COMPLETE (authenticated pass)');
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
