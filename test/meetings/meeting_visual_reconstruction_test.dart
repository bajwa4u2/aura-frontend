import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/domain/meeting_lifecycle.dart';
import 'package:aura/features/meetings/presentation/widgets/meeting_card.dart';
import 'package:aura/features/meetings/presentation/widgets/meeting_surfaces.dart';

/// THE VISUAL RECONSTRUCTION, PINNED.
///
/// Founder ruling 2026-08-25 (visual pass) §28: update tests to reflect the new
/// composition, and do not encode legacy defects as expectations.
///
/// Each test names the thing the live product was doing on the morning of the
/// 25th, so that if any of it comes back, it comes back loudly.
void main() {
  Meeting meeting({
    String title = 'Introduction & Discussion',
    String state = 'SCHEDULED',
    DateTime? at,
    int duration = 30,
  }) =>
      Meeting(
        id: 'm1',
        title: title,
        type: 'SCHEDULED',
        state: state,
        meetingCode: 'ABC',
        joinUrl: '',
        durationMinutes: duration,
        timezone: 'UTC',
        visibility: 'PRIVATE',
        waitingRoomEnabled: true,
        recordingEnabled: false,
        screenShareEnabled: true,
        chatEnabled: true,
        allowGuests: false,
        guestApprovalRequired: true,
        scheduledAt: at ?? DateTime(2026, 8, 26, 14, 30),
        participants: const [],
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
      );

  Future<void> pump(WidgetTester tester, Widget child,
      {Size size = const Size(1400, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );
    await tester.pump();
  }

  group('the meeting card is an object, not a row of fields', () {
    testWidgets('WHEN is answered by a calendar block, not prose',
        (tester) async {
      // The old card put the date inside a sentence: "Tue, Aug 26, 2:30 PM ·
      // Host". You had to read it. A column of cards can now be scanned.
      await pump(
        tester,
        MeetingCard(
          meeting: meeting(),
          relationship: 'Organizer',
          onOpen: () {},
        ),
      );
      expect(find.text('WED'), findsOneWidget);
      expect(find.text('26'), findsOneWidget);
      expect(find.text('AUG'), findsOneWidget);
    });

    testWidgets('the action label is not also rendered as body text',
        (tester) async {
      // THE DEFECT: the old card rendered `_meetingActionLabel(meeting)` as a
      // Text AND as the label of the button directly beneath it.
      await pump(
        tester,
        MeetingCard(
          meeting: meeting(),
          relationship: 'Organizer',
          onOpen: () {},
          onPrimaryAction: () {},
          primaryActionLabel: 'Open',
        ),
      );
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('a live meeting reads as live and offers a filled action',
        (tester) async {
      await pump(
        tester,
        MeetingCard(
          meeting: meeting(state: 'ACTIVE'),
          relationship: 'Organizer',
          onOpen: () {},
          onPrimaryAction: () {},
          primaryActionLabel: 'Join',
        ),
      );
      expect(find.text('Live now'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('a scheduled meeting does not shout — outlined, not filled',
        (tester) async {
      await pump(
        tester,
        MeetingCard(
          meeting: meeting(),
          relationship: 'Organizer',
          onOpen: () {},
          onPrimaryAction: () {},
          primaryActionLabel: 'Open',
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('an instant meeting says NOW rather than inventing a date',
        (tester) async {
      final m = Meeting(
        id: 'm2',
        title: 'Quick sync',
        type: 'INSTANT',
        state: 'ACTIVE',
        meetingCode: 'XYZ',
        joinUrl: '',
        durationMinutes: 15,
        timezone: 'UTC',
        visibility: 'PRIVATE',
        waitingRoomEnabled: false,
        recordingEnabled: false,
        screenShareEnabled: true,
        chatEnabled: true,
        allowGuests: false,
        guestApprovalRequired: false,
        participants: const [],
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
      );
      await pump(tester,
          MeetingCard(meeting: m, relationship: '', onOpen: () {}));
      expect(find.text('NOW'), findsOneWidget);
    });

    testWidgets('it stays readable, and announced, on a phone', (tester) async {
      await pump(
        tester,
        MeetingCard(
          meeting: meeting(),
          relationship: 'Invited',
          dense: true,
          onOpen: () {},
          onPrimaryAction: () {},
          primaryActionLabel: 'Open',
        ),
        size: const Size(390, 840),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Introduction & Discussion'), findsOneWidget);
    });

    testWidgets('the whole card announces itself as one sentence',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MeetingCard(
          meeting: meeting(state: 'ACTIVE'),
          relationship: 'Organizer',
          onOpen: () {},
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('Introduction & Discussion.*Live now')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('states are designed, not absent', () {
    testWidgets('an empty state offers the action that resolves it',
        (tester) async {
      // What this replaces: an AuraCard containing one muted sentence, five
      // times down the page.
      var tapped = 0;
      await pump(
        tester,
        MeetingEmpty(
          icon: Icons.event_available_rounded,
          headline: 'No meetings yet',
          detail: 'They will appear here.',
          action: FilledButton(
            onPressed: () => tapped++,
            child: const Text('New meeting'),
          ),
        ),
      );
      expect(find.text('No meetings yet'), findsOneWidget);
      expect(find.text('They will appear here.'), findsOneWidget);
      await tester.tap(find.text('New meeting'));
      expect(tapped, 1);
    });

    testWidgets('loading shows the SHAPE of what is coming, not a spinner',
        (tester) async {
      await pump(tester, const MeetingSkeletonList(count: 2));
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'a centred spinner came back');
      expect(find.byType(MeetingSkeleton), findsNWidgets(2));
    });

    testWidgets('the skeleton fills its column rather than centring',
        (tester) async {
      // Seen on the live site: the placeholders sized to their content and
      // sat centred, so the loading state did not stand in for the list.
      await pump(tester, const MeetingSkeletonList(count: 2));
      final w = tester.getSize(find.byType(MeetingSkeleton).first).width;
      expect(w, greaterThan(600),
          reason: 'the skeleton is not standing in for a full-width card');
    });

    testWidgets('an error speaks the product\'s language, not Dart\'s',
        (tester) async {
      // What this replaces: Text('Unable to load. $e').
      await pump(
        tester,
        const MeetingError(
          what: 'your meetings',
          technical: 'DioException [connection error]: SocketException',
        ),
      );
      expect(find.textContaining('Could not load your meetings'),
          findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing,
          reason: 'a raw exception reached the screen');
    });

    testWidgets('a section with a count says the count', (tester) async {
      await pump(
        tester,
        const MeetingSection(
          title: 'Needs attention',
          count: 3,
          child: SizedBox(height: 10),
        ),
      );
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('status is carried by words, never by colour alone', () {
    testWidgets('each tone still names itself', (tester) async {
      for (final tone in MeetingChipTone.values) {
        await pump(
          tester,
          MeetingStatusChip(label: 'Live now', tone: tone),
        );
        expect(find.text('Live now'), findsOneWidget, reason: '$tone');
      }
    });
  });

  group('phase drives the card, and every phase is covered', () {
    testWidgets('no phase renders an empty status', (tester) async {
      for (final state in ['DRAFT', 'SCHEDULED', 'ACTIVE', 'ENDED',
        'CANCELLED', 'NONSENSE']) {
        await pump(
          tester,
          MeetingCard(
            meeting: meeting(state: state),
            relationship: '',
            onOpen: () {},
          ),
        );
        expect(tester.takeException(), isNull, reason: state);
        // The chip is always present and always says something.
        expect(find.byType(MeetingStatusChip), findsOneWidget, reason: state);
      }
    });

    testWidgets('phase comes from the one authority', (tester) async {
      expect(meeting(state: 'ACTIVE').phase, MeetingPhase.active);
      expect(meeting(state: 'CANCELLED').phase, MeetingPhase.cancelled);
    });
  });
}
