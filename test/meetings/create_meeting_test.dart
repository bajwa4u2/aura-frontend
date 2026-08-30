import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/institutions/data/institutions_repository.dart';
import 'package:aura/features/institutions/domain/institution.dart';
import 'package:aura/features/meetings/application/meetings_provider.dart';
import 'package:aura/features/meetings/presentation/create_meeting_screen.dart';

/// No network. Left unmocked, the screen's providers open real Dio requests
/// whose connect timeouts outlive the test and trip `!timersPending`.
class _StubInstitutions extends InstitutionsRepository {
  _StubInstitutions() : super(Dio());

  @override
  Future<Institution> getById(String id) async => Institution(
    id: id,
    name: 'Aura Platform LLC',
    slug: 'aura-platform-llc',
    domain: 'auraplatform.org',
    jurisdiction: 'US',
    description: '',
    website: '',
    isVerified: true,
  );

  @override
  Future<Map<String, dynamic>> listMembers(String institutionId) async => {
    'callerRole': 'OWNER',
    'members': const [],
  };
}

/// CREATE MEETING — founder closeout batch, Part A.
///
/// The ruling: open and experience the released flow first, then reconstruct
/// so it answers, naturally — what am I creating, for whom, when, who can
/// participate, what happens when I create it.
///
/// Each test names what the live form at
/// /institution/aura-platform-llc/meetings/new was doing on 2026-08-25.
void main() {
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1400, 950),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          institutionsRepositoryProvider.overrideWithValue(_StubInstitutions()),
          myAvailabilityProfilesProvider.overrideWith((ref) async => const []),
          currentBookingIdentityProvider.overrideWith((ref) async => null),
        ],
        // AuraScaffold is not a Material Scaffold; in the app the router
        // shell supplies the Material ancestor its TextFields require.
        child: const MaterialApp(
          home: Material(child: CreateMeetingScreen(institutionId: 'i1')),
        ),
      ),
    );
    await tester.pump();
  }

  group('the title is asked for, not answered', () {
    testWidgets('the field does NOT arrive pre-filled with "Meeting"', (
      tester,
    ) async {
      // THE DEFECT: initState set _titleCtrl.text = 'Meeting'. Anyone who did
      // not overwrite it created a meeting called Meeting, and production has
      // several. It was then echoed back as the last "Review" line, so the
      // form ticked a green check at a title nobody had chosen.
      await open(tester);
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Meeting title').first,
      );
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('it asks the question instead', (tester) async {
      await open(tester);
      expect(find.text('What is this meeting for?'), findsOneWidget);
      expect(find.text('Everyone invited sees this first.'), findsOneWidget);
    });

    testWidgets(
      'and the question is actually VISIBLE when the field is empty',
      (tester) async {
        // Caught on the live site after the first deploy of this change: an
        // empty, unfocused Material field draws its LABEL inside the box and
        // suppresses the hint, so the question never appeared.
        await open(tester);
        final field = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Meeting title').first,
        );
        expect(
          field.decoration?.floatingLabelBehavior,
          FloatingLabelBehavior.always,
        );
      },
    );
  });

  group('the summary answers the founder\'s four questions', () {
    testWidgets('what, when, how long, who — each labelled', (tester) async {
      await open(tester);
      expect(find.text('When'), findsOneWidget);
      expect(find.text('How long'), findsOneWidget);
      expect(find.text('Who'), findsOneWidget);
    });

    testWidgets('an unnamed meeting says so rather than showing a fake title', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Untitled meeting'), findsOneWidget);
    });

    testWidgets('it never invents a name for the convening institution', (
      tester,
    ) async {
      // "Owning institution" reached production as the convener's NAME for as
      // long as the institution record took to load.
      await open(tester);
      expect(find.text('Owning institution'), findsNothing);
    });

    testWidgets('what is still MISSING is shown as missing', (tester) async {
      // THE DEFECT: every line carried the same green check whether or not it
      // represented anything satisfied, and the only signal that participants
      // were required arrived as a snackbar on submit — referring to a toggle
      // that was several screens below the fold.
      await open(tester);
      expect(find.text('Choose who is in this meeting'), findsOneWidget);
    });

    testWidgets('it renames the meeting as you type it', (tester) async {
      // Without a controller listener the panel read "Untitled meeting" until
      // an unrelated control forced a rebuild. That was survivable only while
      // the title arrived pre-filled — removing the default exposed it.
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Meeting title').first,
        'Quarterly review',
      );
      await tester.pump();
      expect(find.text('Quarterly review'), findsWidgets);
      expect(find.text('Untitled meeting'), findsNothing);
    });
  });

  group('the wide layout keeps the review context', () {
    // THE DEFECT: the whole screen was ONE ListView with the review pane
    // inside it, so the panel saying what was still missing left the window
    // exactly when you scrolled to the section that supplies it. A wrapper
    // could not fix this; the scroll architecture had to change.

    /// The scrollable that actually owns a widget.
    ScrollableState owner(WidgetTester tester, Finder f) =>
        Scrollable.of(tester.element(f));

    testWidgets('the form and the review rail are SEPARATE scrollables', (
      tester,
    ) async {
      await open(tester);
      expect(
        owner(tester, find.text('When')),
        isNot(same(owner(tester, find.text('Agenda or description')))),
        reason: 'the review pane is back inside the form scroll view',
      );
    });

    testWidgets('scrolling the form does NOT move the review pane', (
      tester,
    ) async {
      // The behavioural proof, and the one a wrapper could never pass.
      await open(tester);
      final before = tester.getTopLeft(find.text('When'));
      // Dragged from the FORM, not from a field's own label. The label belongs
      // to the agenda field's decoration, so once that field grows with its
      // content the label is no longer a hit-testable point — and the intent
      // here was never "drag this particular word", it was "scroll the form".
      // The sibling test below already anchors on the ListView for the same
      // reason.
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('When')),
        before,
        reason: 'the review pane travelled with the form again',
      );
      expect(
        find.text('External invitees'),
        findsOneWidget,
        reason: 'the form did not actually scroll',
      );
    });

    testWidgets(
      'the primary action sits with the summary, not below the form',
      (tester) async {
        await open(tester);
        final field = tester.getTopLeft(find.text('Agenda or description')).dx;
        final button = tester
            .getTopLeft(find.widgetWithText(FilledButton, 'Create meeting'))
            .dx;
        expect(
          button,
          greaterThan(field),
          reason: 'the button is not in the review rail',
        );
        expect(
          owner(tester, find.widgetWithText(FilledButton, 'Create meeting')),
          same(owner(tester, find.text('When'))),
        );
      },
    );

    testWidgets('nothing nests a scrollable inside the page scrollable', (
      tester,
    ) async {
      // The member picker was a fixed 220px well with its own ListView. On a
      // narrow window it sat across the middle of the form and swallowed the
      // page's scroll gestures, so the button that creates the meeting was
      // unreachable by touch.
      await open(tester, size: const Size(700, 900));
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('narrow keeps ONE column, review directly above the button', (
      tester,
    ) async {
      await open(tester, size: const Size(700, 900));
      // One column means the review pane is BELOW the form, so a lazy list has
      // not built it yet — scroll to it the way a person would.
      //
      // Scrolls until the BUTTON is built, not merely until the review pane
      // appears. The assertion below compares the two positions, so both have
      // to exist; stopping at the review pane left the button still below the
      // fold and unbuilt the moment any field above it changed height, which
      // made this test a hostage to unrelated form layout rather than a check
      // on ordering.
      for (var i = 0;
          i < 20 &&
              find.widgetWithText(FilledButton, 'Create meeting').evaluate().isEmpty;
          i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pump();
      }
      expect(
        find.text('When'),
        findsOneWidget,
        reason: 'the review pane is not reachable by scrolling',
      );
      expect(
        owner(tester, find.text('When')),
        same(owner(tester, find.text('External invitees'))),
        reason: 'the narrow layout split into two scrollables',
      );
      final review = tester.getTopLeft(find.text('When')).dy;
      final button = tester
          .getTopLeft(find.widgetWithText(FilledButton, 'Create meeting'))
          .dy;
      expect(button, greaterThan(review));
    });

    testWidgets('the form is not clipped — its last section is reachable', (
      tester,
    ) async {
      await open(tester);
      await tester.drag(
        find.text('Agenda or description'),
        const Offset(0, -1200),
      );
      await tester.pump();
      expect(find.text('External invitees'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the transition between wide and narrow does not throw', (
      tester,
    ) async {
      await open(tester);
      for (final w in [1400.0, 1000.0, 700.0, 1200.0, 480.0]) {
        tester.view.physicalSize = Size(w, 900);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'at ${w}px');
        // The form survives every width. The review pane is only guaranteed
        // on screen in the wide layout, where it is pinned beside the form.
        expect(find.text('Meeting title'), findsOneWidget, reason: 'at ${w}px');
        if (w >= 1100) {
          expect(find.text('When'), findsOneWidget, reason: 'at ${w}px');
        }
      }
    });
  });

  group('the form does not contradict itself', () {
    testWidgets(
      'it does not say "no members selected" while ALL are included',
      (tester) async {
        // Seen live: "All active members" ON, and the line directly beneath it
        // read "No internal members selected" — the meeting had everyone and
        // the form said nobody.
        await open(tester);
        expect(find.text('No internal members selected'), findsOneWidget);
        await tester.tap(find.text('All active members'));
        await tester.pump();
        expect(find.text('No internal members selected'), findsNothing);
      },
    );
  });

  group('the screen is about creating a meeting', () {
    testWidgets('no booking-page card sits between the form and the button', (
      tester,
    ) async {
      // THE DEFECT: a Booking page section — duplicated from the Meetings
      // landing, showing a raw URL — sat after External invitees, so the
      // primary action of the screen was below a card about another feature.
      await open(tester);
      expect(find.text('Booking page'), findsNothing);
    });

    testWidgets('the subtitle speaks product, not schema', (tester) async {
      // "Internal participants are bound at creation." — `bound` is how the
      // backend describes the write, not something a person needs to know.
      await open(tester);
      expect(find.textContaining('bound at creation'), findsNothing);
      expect(
        find.text(
          'Give the meeting a purpose, decide who is in it, '
          'and choose when.',
        ),
        findsOneWidget,
      );
    });
  });
}
