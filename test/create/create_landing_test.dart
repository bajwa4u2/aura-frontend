import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/features/admin/domain/operator_entry.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/create/presentation/create_hub_screen.dart';

/// CREATE — THE LANDING SURFACE.
///
/// Founder ruling 2026-08-25. Every assertion here corresponds to a defect
/// found by using the live surface, not to a preference about layout.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// Mounts Create with a real router so navigation is observable.
  Future<GoRouter> pump(
    WidgetTester tester, {
    required AsyncValue<InstitutionAccess> institution,
    bool admin = false,
    Size size = const Size(1400, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/create',
      routes: [
        GoRoute(
            path: '/create', builder: (_, __) => const CreateHubScreen()),
        for (final p in const [
          '/compose',
          '/articles/write',
          '/messages/new',
          '/announcements/create',
        ])
          GoRoute(path: p, builder: (_, __) => const Scaffold(body: Text('X'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Create asks the audit-safe operator question rather than reading
          // the display cache, which is only warm after a visit to /admin.
          // A platform admin who had not opened the admin workspace this
          // session was silently routed to a surface that cannot publish.
          canEnterOperatorConsoleProvider.overrideWithValue(admin),
          institutionAccessProvider.overrideWith((ref) async {
            if (institution.isLoading) {
              // Never completes: "still finding out" is a state the surface
              // must render honestly, not a state it may skip.
              return Completer<InstitutionAccess>().future;
            }
            return institution.value!;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return router;
  }

  const none = AsyncValue<InstitutionAccess>.data(
      InstitutionAccess(state: InstitutionAccessState.none));
  const speaker = AsyncValue<InstitutionAccess>.data(
      InstitutionAccess(state: InstitutionAccessState.authorizedSpeaker));

  group('every creation outcome is reachable', () {
    testWidgets('all three person outcomes are on screen at laptop size',
        (tester) async {
      // The defect: four sections of one card each made the surface taller
      // than the viewport, so Message — a primary human intention — sat below
      // the fold and could not be reached.
      await pump(tester, institution: none);
      for (final title in ['Message', 'Post', 'Article']) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('and on a phone-sized surface', (tester) async {
      await pump(tester, institution: none, size: const Size(1080, 2400));
      for (final title in ['Message', 'Post', 'Article']) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('the outcomes are not hidden in a horizontal rail',
        (tester) async {
      // AdaptiveCardGrid's narrow fallback is a rail, which puts choices
      // off-screen — the same defect wearing different clothes. Create pins
      // grid mode, so a narrow viewport stacks rather than scrolls sideways.
      await pump(tester, institution: none, size: const Size(700, 1600));
      for (final title in ['Message', 'Post', 'Article']) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });
  });

  group('a creation entered from Create returns to Create', () {
    testWidgets('the cards PUSH, so the journey survives', (tester) async {
      // The defect, verified live before the change: the cards used `go`,
      // which replaces the stack, so cancelling the composer landed on /home
      // and the person's journey was erased.
      final router = await pump(tester, institution: none);
      expect(router.canPop(), isFalse);

      final postCard =
          find.ancestor(of: find.text('Post'), matching: find.byType(InkWell));
      await tester.tap(postCard);
      await tester.pumpAndSettle();

      // The property that matters, and the one the live defect violated: a
      // predecessor now EXISTS, so the governed Cancel unwinds to Create
      // instead of falling back to /home.
      expect(router.canPop(), isTrue,
          reason: 'entering a creation replaced the stack, so there would be '
              'nothing for Cancel to return to');
      expect(find.text('Post'), findsNothing,
          reason: 'the destination did not open');

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Post'), findsOneWidget,
          reason: 'cancelling did not return to Create');
    });

    testWidgets('every card behaves the same way', (tester) async {
      for (final title in const ['Message', 'Article']) {
        final router = await pump(tester, institution: none);
        expect(router.canPop(), isFalse);
        await tester.tap(
            find.ancestor(of: find.text(title), matching: find.byType(InkWell)));
        await tester.pumpAndSettle();
        expect(router.canPop(), isTrue,
            reason: '$title replaced the stack instead of preserving it');
        router.pop();
        await tester.pumpAndSettle();
      }
    });
  });

  group('authority is presented honestly', () {
    testWidgets('no Announcement card without the authority', (tester) async {
      await pump(tester, institution: none);
      expect(find.text('Announcement'), findsNothing);
    });

    testWidgets('an authorized speaker gets it', (tester) async {
      await pump(tester, institution: speaker);
      expect(find.text('Announcement'), findsOneWidget);
    });

    testWidgets('a platform admin gets it', (tester) async {
      await pump(tester, institution: none, admin: true);
      expect(find.text('Announcement'), findsOneWidget);
    });

    testWidgets('WHILE RESOLVING it says so rather than implying absence',
        (tester) async {
      // The defect: institution access was read with `orElse: none`, so "still
      // finding out" rendered as "you cannot" — and the card appeared later,
      // unannounced. Saying nothing would state that these three are all there
      // is, before that is known.
      await pump(tester, institution: const AsyncValue.loading());
      expect(find.text('Announcement'), findsNothing);
      expect(find.textContaining('Checking what else you can publish'),
          findsOneWidget);
    });
  });

  group('the surface says what Aura is for', () {
    testWidgets('public-first, and not a list of the cards below it',
        (tester) async {
      await pump(tester, institution: none);
      expect(find.textContaining('stands up'), findsOneWidget);
      // The old hero enumerated the same four things the cards enumerate.
      expect(find.textContaining('a message, a post, an article'), findsNothing);
    });

    testWidgets('Create is a root: it offers no way back of its own',
        (tester) async {
      // ROOT_NO_RETURN. The shell owns movement between primaries; a Back here
      // would be a lie. (The governed frame reaches the same conclusion; this
      // pins that the screen does not add one.)
      await pump(tester, institution: none);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('each outcome is a labelled button for assistive tech',
        (tester) async {
      await pump(tester, institution: none);
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('^Message\\.')),
        findsOneWidget,
        reason: 'a creation outcome is not announced as an actionable button',
      );
      handle.dispose();
    });
  });
}
