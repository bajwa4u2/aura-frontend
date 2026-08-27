// TRACE LIFECYCLE PROOF — the client half.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHAT MAKES THIS DIFFERENT FROM THE WIDGET TESTS
//
// `test/media/trace_test.dart` builds its own account and asserts the surface
// renders it. That proves: IF DERIVED STATE EXISTS, THE UI CAN DISPLAY IT. It
// proves nothing about whether the state is ever produced, or whether the shape
// the server sends is the shape this client reads.
//
// Both of those failed in production while every such test stayed green.
//
// So this test does not author its input. It loads
// `test/fixtures/trace-account.golden.json` — a file the BACKEND produced, by
// running its real examination path over real bytes carrying a real Content
// Credentials manifest — and pushes it through the real presenter on a real
// device. The backend's own lifecycle suite asserts it still produces that
// exact file, so the two halves cannot drift into a server emitting one shape
// and a client certified against another.
//
// The chain this closes:
//
//     real provenance-bearing bytes   (proven in the backend suite)
//       → examination → evidence → disclosure → public resolution
//       → THIS FILE
//       → client model
//       → real media presenter
//       → TR visible
//       → TR opened
//       → the curated public disclosure
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/media/aura_media_group.dart';
import 'package:aura/core/media/media_interaction_profile.dart';
import 'package:aura/core/media/trace/aura_trace.dart';
import 'package:aura/features/feed/domain/feed_media.dart';

/// The account the backend produced. Never authored here.
late final Map<String, dynamic> goldenAccount;

FeedMedia mediaWithGoldenTrace() => FeedMedia(
      id: 'lifecycle',
      mediaId: 'lifecycle',
      mediaType: 'IMAGE',
      mimeType: 'image/png',
      visibility: 'PUBLIC',
      url: 'https://example.invalid/lifecycle.png',
      width: 1600,
      height: 1200,
      trace: AuraTrace.fromJson(goldenAccount),
    );

/// Bring a part of the Trace surface into view, the way a reader would.
///
/// A RICH account is taller than the inspector on purpose — history, evidence
/// and publication are more than fits, and scrolling is the real interaction.
/// Asserting only on what happens to be above the fold would certify the
/// viewport rather than the product.
Future<void> revealInTrace(WidgetTester tester, Finder target) async {
  if (target.evaluate().isNotEmpty) return;

  // DRIVE THE SCROLL POSITION DIRECTLY.
  //
  // Gesture-based helpers fight the sheet on touch: a DraggableScrollableSheet
  // answers an upward drag by GROWING until it reaches its maximum and only
  // then by scrolling, so `scrollUntilVisible` spends its attempts resizing and
  // reports a target that is merely below the fold as absent. Moving the
  // controller is unambiguous, and what is being proven here is that the
  // content is present and reachable — not which gesture reaches it.
  final scrollable = find.byType(Scrollable).last;
  final state = tester.state<ScrollableState>(scrollable);

  for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
    final next = state.position.pixels + 120;
    if (next > state.position.maxScrollExtent) {
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pumpAndSettle();
      break;
    }
    state.position.jumpTo(next);
    await tester.pumpAndSettle();
  }
}

Future<void> host(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SizedBox(width: 420, child: child))),
  );
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Loaded from the ASSET BUNDLE, not the host filesystem — the golden has
    // to travel to the device, and on Android there is no host path to read.
    final raw = await rootBundle.loadString(
      'test/fixtures/trace-account.golden.json',
    );
    goldenAccount = jsonDecode(raw) as Map<String, dynamic>;
  });

  group('THE GOLDEN IS REAL', () {
    test('it is the backend account, not something authored here', () {
      // Guard against a fixture that has been emptied or replaced. Without
      // this, every assertion below could pass vacuously — which is exactly
      // how a green suite came to mean nothing before.
      expect(goldenAccount['available'], isTrue);
      expect(goldenAccount['headline'], 'Created with AI');
      expect((goldenAccount['evidence'] as List), isNotEmpty);
    });

    test('the client model reads every part the server sent', () {
      final t = AuraTrace.fromJson(goldenAccount);
      expect(t.available, isTrue);
      expect(t.headline, 'Created with AI');
      expect(t.source, 'OpenAI Media Service API');
      expect(t.summary, isNotNull);
      expect(t.evidence, isNotEmpty);
      expect(t.history, isNotEmpty);
      expect(t.publication, isNotNull);
      expect(t.uncertainty, isNotEmpty);
      expect(t.about, isNotEmpty);
    });
  });

  group('THE PRESENTER — real media, real device', () {
    testWidgets('a SINGLE media item carrying the golden shows TR',
        (tester) async {
      // The single-media path is the one that was invisible in production: a
      // post with one image never enters the collage the group assertions
      // exercised.
      await host(tester, AuraMediaGroup(items: [mediaWithGoldenTrace()]));
      expect(find.text('TR'), findsOneWidget);
    });

    testWidgets('opening TR gives the curated account, in order',
        (tester) async {
      await host(tester, AuraMediaGroup(items: [mediaWithGoldenTrace()]));
      await tester.tap(find.text('TR'));
      await tester.pumpAndSettle();

      // THE MEANING FIRST.
      //
      // `findsWidgets`, not `findsOneWidget`: on a touch client the sheet
      // opens tall enough that the history is visible too, and its first step
      // is legitimately the same words — "Created with AI → Entered Aura →
      // Published" reads correctly. The headline and the first event being the
      // same event is not a duplicate.
      expect(find.text('Created with AI'), findsWidgets);
      // Same reason as the headline: the source line and the creation step's
      // detail both name the producing system, which is correct on both.
      expect(find.text('OpenAI Media Service API'), findsWidgets);
      expect(find.textContaining('generated using AI'), findsWidgets);

      // THE EVIDENCE, including who the file names and when it says it was made.
      expect(find.text('Evidence'), findsOneWidget);
      expect(find.textContaining('Signed in the file by OpenAI OpCo, LLC'),
          findsOneWidget);

      // THE LIMIT, never omitted.
      expect(
        find.textContaining('not independently verified the credential signer'),
        findsOneWidget,
      );

      // THE HISTORY, as a sequence.
      await revealInTrace(tester, find.text('History'));
      expect(find.text('History'), findsOneWidget);
      await revealInTrace(tester, find.text('Entered Aura'));
      expect(find.text('Entered Aura'), findsOneWidget);

      // PUBLICATION AS ITS OWN SECTION — never presented as content origin.
      //
      await revealInTrace(tester, find.text('Publication'));
      expect(find.text('Publication'), findsOneWidget);
      expect(find.text('M S Bajwa'), findsOneWidget);

      // AND THE BOUNDARY, which is PINNED — it needed no scrolling to reach.
      expect(find.textContaining('does not by itself determine'), findsOneWidget);
    });

    testWidgets('the surface never states a verification it does not have',
        (tester) async {
      await host(tester, AuraMediaGroup(items: [mediaWithGoldenTrace()]));
      await tester.tap(find.text('TR'));
      await tester.pumpAndSettle();

      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .join(' ');
      expect(rendered, isNot(contains('verified ai')));
      expect(rendered, isNot(contains('human-created')));
      expect(rendered, isNot(contains('authentic')));
      // "cryptographically verified" is a real public label — it must simply
      // never appear for evidence Aura did not cryptographically verify.
      expect(rendered, isNot(contains('cryptographically verified')));
    });

    testWidgets('opens in the idiom THIS platform uses', (tester) async {
      await host(tester, AuraMediaGroup(items: [mediaWithGoldenTrace()]));
      await tester.tap(find.text('TR'));
      await tester.pumpAndSettle();

      final touch = MediaInteractionProfile.resolve(canDecodeVideo: true)
              .pointer ==
          PointerModel.touch;
      if (touch) {
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      } else {
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        expect(find.text('Close'), findsOneWidget);
      }
      // The facts are the same facts either way.
      expect(find.text('Created with AI'), findsWidgets);
    });

    testWidgets('media with nothing to disclose still shows no TR',
        (tester) async {
      // The negative control. If TR appeared here the mark would be decoration.
      await host(
        tester,
        AuraMediaGroup(items: [
          FeedMedia(
            id: 'plain',
            mediaId: 'plain',
            mediaType: 'IMAGE',
            mimeType: 'image/png',
            visibility: 'PUBLIC',
            url: 'https://example.invalid/plain.png',
          ),
        ]),
      );
      expect(find.text('TR'), findsNothing);
    });
  });
}
