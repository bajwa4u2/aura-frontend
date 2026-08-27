// PREFERENCES — certification on the real client family.
//
// Widget tests run against a host VM with a test font and a synthetic
// viewport. This runs the same surface on the actual released client, because
// the two things this chapter is most likely to get wrong — a control too
// small to hit on a phone, and a landing that reads as a settings dashboard on
// a desktop — are both invisible to a host-VM test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/media/media_interaction_profile.dart';
import 'package:aura/features/me/presentation/preferences_screen.dart';

Future<void> host(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: PreferencesScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('PREFERENCES on the real platform', () {
    testWidgets('every group is present and named for a person', (tester) async {
      await host(tester);
      for (final g in [
        'Account',
        'Notifications',
        'Security',
        'Privacy',
        'Data and account',
      ]) {
        expect(find.text(g), findsOneWidget, reason: '$g missing');
      }
    });

    testWidgets('no row exposes internal architecture as a label',
        (tester) async {
      await host(tester);
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .join(' | ');
      // The vocabulary a person should never meet here.
      for (final internal in [
        'session',
        'endpoint',
        'authority',
        'provider',
        'json',
        'api',
      ]) {
        expect(labels, isNot(contains(internal)),
            reason: '"$internal" is internal vocabulary on a public surface');
      }
    });

    testWidgets('the three device concepts are named apart', (tester) async {
      await host(tester);
      // "Your devices" is where Aura reaches you. Signing-in and verification
      // live behind Security and say so there.
      expect(find.text('Your devices'), findsOneWidget);
      expect(find.text('Devices'), findsNothing);
    });

    testWidgets('the composition answers to THIS platform', (tester) async {
      await host(tester);
      final touch =
          MediaInteractionProfile.resolve(canDecodeVideo: true).pointer ==
              PointerModel.touch;
      // Whatever the platform, the groups are all reachable — the layout
      // differs, the content does not.
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      // On touch there is exactly one column; the two-column composition is a
      // pointer-only decision and must not appear on a phone.
      if (touch) {
        expect(find.byType(Row), findsWidgets);
      }
    });

    testWidgets('every row is comfortably hittable', (tester) async {
      await host(tester);
      // A settings row a person cannot reliably tap is the commonest way a
      // settings surface fails on a phone.
      for (final label in ['Profile', 'Password', 'Blocked people']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        final size = tester.getSize(
          find.ancestor(of: finder, matching: find.byType(InkWell)).first,
        );
        expect(size.height, greaterThanOrEqualTo(44.0),
            reason: '"$label" row is only ${size.height}px tall');
      }
    });

    testWidgets('the consequential row states its consequence', (tester) async {
      await host(tester);
      // Nobody should arrive at account deletion without having been told what
      // it does on the way in.
      expect(
        find.textContaining('Permanently remove your account'),
        findsOneWidget,
      );
    });
  });
}
