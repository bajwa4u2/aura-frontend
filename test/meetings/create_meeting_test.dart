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
  Future<Map<String, dynamic>> listMembers(String institutionId) async =>
      {'callerRole': 'OWNER', 'members': const []};
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
  Future<void> open(WidgetTester tester, {Size size = const Size(1400, 950)}) async {
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
    testWidgets('the field does NOT arrive pre-filled with "Meeting"',
        (tester) async {
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
  });

  group('the summary answers the founder\'s four questions', () {
    testWidgets('what, when, how long, who — each labelled', (tester) async {
      await open(tester);
      expect(find.text('When'), findsOneWidget);
      expect(find.text('How long'), findsOneWidget);
      expect(find.text('Who'), findsOneWidget);
    });

    testWidgets('an unnamed meeting says so rather than showing a fake title',
        (tester) async {
      await open(tester);
      expect(find.text('Untitled meeting'), findsOneWidget);
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

  group('the screen is about creating a meeting', () {
    testWidgets('no booking-page card sits between the form and the button',
        (tester) async {
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
        find.text('Give the meeting a purpose, decide who is in it, '
            'and choose when.'),
        findsOneWidget,
      );
    });
  });
}
