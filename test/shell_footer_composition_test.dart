// Guards the public CLOSING — the last movement of every public page.
//
// The footer this replaces was a sitemap: three headed link columns, a
// paragraph re-defining the platform, an attribution lockup and the ecosystem
// band. Its geometry test asked whether the columns sat to the right of the
// brand block, which is the right question to ask about a warehouse and the
// wrong one to ask about a closing.
//
// What is guarded now is what the closing is FOR:
//
//   * it ends with an invitation, and that invitation composes beside the
//     closing thought on a desktop and beneath it on a phone;
//   * there is exactly ONE relationship path, named "Start a conversation".
//     "Contact" and "Help" were two names for one destination (`/contact`
//     redirects to `/support/agent`) and both are retired as public taxonomy;
//   * the closing is set to a READING measure, not the full page band — a
//     closing thought stretched across 1360 px reads as a banner;
//   * the destinations offered are the three that earn a place, with no
//     section headings above them.
//
// Geometry, not goldens: the relationships above survive typography changes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/app/shell/shell_shared.dart';
import 'package:aura/core/ui/aura_responsive.dart';

/// Pumps the closing inside the same container the public estate gives it:
/// a centred page band, with the footer taking the full width of it.
Future<void> _pumpFooter(WidgetTester tester, double viewportWidth) async {
  tester.view.physicalSize = Size(viewportWidth, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                // 920 = AuraScaffold's default page width, the container the
                // public home actually hands the closing.
                constraints: const BoxConstraints(maxWidth: 920),
                child: const SizedBox(
                  width: double.infinity,
                  child: ShellFooter(),
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(path: '/support/agent', builder: (_, __) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('the closing composes', () {
    testWidgets('invitation sits beside the thought at the public home width', (
      tester,
    ) async {
      await _pumpFooter(tester, 1440);

      final thought = tester.getRect(find.textContaining('Say it in the open'));
      final invitation = tester.getRect(find.text('Start a conversation'));

      expect(
        invitation.left,
        greaterThan(thought.right),
        reason: 'on a desktop the invitation belongs beside the closing '
            'thought, not stacked under it',
      );
    });

    testWidgets('invitation drops below the thought on a phone', (
      tester,
    ) async {
      await _pumpFooter(tester, 400);

      final thought = tester.getRect(find.textContaining('Say it in the open'));
      final invitation = tester.getRect(find.text('Start a conversation'));

      expect(
        invitation.top,
        greaterThan(thought.bottom),
        reason: 'on a phone the closing must stack',
      );
    });
  });

  group('the closing offers one relationship path', () {
    testWidgets('Start a conversation is present exactly once', (tester) async {
      await _pumpFooter(tester, 1440);
      expect(find.text('Start a conversation'), findsOneWidget);
    });

    testWidgets('Contact and Help are retired as public taxonomy', (
      tester,
    ) async {
      await _pumpFooter(tester, 1440);

      // Founder ruling: contact is retired as public taxonomy and must not be
      // resurrected as a parallel destination. "Help" pointed at the same
      // route under a second name, which is the same defect wearing a
      // different label.
      expect(find.text('Contact'), findsNothing);
      expect(find.text('CONTACT'), findsNothing);
      expect(find.text('Help'), findsNothing);
      expect(find.text('Support'), findsNothing);
      expect(find.text('SUPPORT'), findsNothing);
    });
  });

  group('the closing is a closing, not a sitemap', () {
    testWidgets('the destinations are the three that earn a place', (
      tester,
    ) async {
      await _pumpFooter(tester, 1440);

      for (final d in const ['Mission', 'Discover', 'Institutions']) {
        expect(find.text(d), findsOneWidget, reason: '$d should be offered');
      }
    });

    testWidgets('there are no section headings above the destinations', (
      tester,
    ) async {
      await _pumpFooter(tester, 1440);

      // The retired composition headed one- and two-link columns with AURA /
      // SUPPORT / LEGAL. Headings for a structure that is not there.
      expect(find.text('AURA'), findsNothing);
      expect(find.text('LEGAL'), findsNothing);
    });

    testWidgets('the company is named once, and it is the link', (
      tester,
    ) async {
      await _pumpFooter(tester, 1440);

      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);

      // Founder ruling: one mention, carrying the link to the company. The
      // retired composition said it twice in three lines, and said "Built by".
      expect(
        find.textContaining('Aura Platform LLC'),
        findsOneWidget,
        reason: 'the company must appear exactly once in the closing',
      );
      expect(find.text('A product of Aura Platform LLC.'), findsOneWidget);
      expect(find.textContaining('Built by'), findsNothing);

      // No copyright line. Neither sibling prints one.
      expect(find.textContaining('©'), findsNothing);

      // The invitation must read louder than the legal line, or the closing
      // has no centre of gravity.
      final invitation = tester.widget<Text>(
        find.text('Start a conversation'),
      );
      final privacy = tester.widget<Text>(find.text('Privacy'));
      expect(
        invitation.style!.fontSize!,
        greaterThan(privacy.style!.fontSize!),
      );
    });

    testWidgets('the bottom row is at parity with the estate', (tester) async {
      // Orchestrate and Bajwa Writes both close on company-name-left,
      // sibling-products-right, each omitting itself. Aura does the same.
      await _pumpFooter(tester, 1440);
      for (final s in const ['Orchestrate', 'Bajwa Writes', 'Founder']) {
        expect(find.text(s), findsOneWidget, reason: '$s missing');
      }
      // Aura does not link to itself, and the whole-estate directory (which
      // led with "Company" and included Aura) is not what parity restores.
      expect(find.text('Company'), findsNothing);
    });
  });

  group('made with support', () {
    testWidgets('the band carries the estate label, sentence and marks', (
      tester,
    ) async {
      await _pumpFooter(tester, 1440);

      expect(find.text('MADE WITH SUPPORT'), findsOneWidget);
      expect(
        find.textContaining('Aura is being built in an environment'),
        findsOneWidget,
      );
      for (final m in const [
        'Microsoft for Startups',
        'Google for Startups',
        'AWS Activate',
      ]) {
        expect(
          find.bySemanticsLabel(m),
          findsOneWidget,
          reason: '$m mark missing from the support band',
        );
      }
    });

    testWidgets('the support band sits above the closing', (tester) async {
      await _pumpFooter(tester, 1440);
      final band = tester.getRect(find.text('MADE WITH SUPPORT'));
      final closing = tester.getRect(
        find.textContaining('Say it in the open'),
      );
      expect(
        band.bottom,
        lessThan(closing.top),
        reason: 'the estate puts the support band above the footer',
      );
    });
  });

  test('the closing shares the page band it closes', () {
    // A closing set to a band of its own stood 190 px inside the left edge of
    // every section above it, which reads as a different page rather than the
    // last movement of this one. The prose inside is still held to a reading
    // measure; the BAND is the page's.
    expect(ShellFooter.maxWidth, kHeroWidth);
  });

  testWidgets('the closing thought is held to a reading measure', (
    tester,
  ) async {
    await _pumpFooter(tester, 1440);
    final thought = tester.getRect(find.textContaining('Say it in the open'));
    expect(
      thought.width,
      lessThan(700),
      reason: 'a closing thought set across the whole band reads as a banner',
    );
  });
}
