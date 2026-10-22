import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/presentation/realtime_room_screen.dart';
import 'package:aura/features/realtime/presentation/widgets/consent_prompts.dart';

/// EVERYONE'S YES (founder-approved design, 22 Oct 2026): going live and
/// recording ask every person; a viewer whose live ended is told so.
void main() {
  group('who is asked', () {
    test('a person still to answer is asked', () {
      expect(
        shouldAskForConsent(
          {'requestedByUserId': 'ana', 'pendingUserIds': ['bilal']},
          me: 'bilal',
          requesterKey: 'requestedByUserId',
        ),
        isTrue,
      );
    });
    test('the person who asked is never asked', () {
      expect(
        shouldAskForConsent(
          {'requestedByUserId': 'ana', 'pendingUserIds': ['ana', 'bilal']},
          me: 'ana',
          requesterKey: 'requestedByUserId',
        ),
        isFalse,
      );
    });
    test('a guest waiting to be asked about recording is asked', () {
      expect(
        shouldAskForConsent(
          {
            'requestedByUserId': 'mia',
            'pendingUserIds': <String>[],
            'pendingParticipants': [
              {'kind': 'guest', 'id': 'g1', 'participantId': 'p-g1'},
            ],
          },
          me: 'g1',
          requesterKey: 'requestedByUserId',
        ),
        isTrue,
      );
    });
    test('someone who already answered is not asked again', () {
      expect(
        shouldAskForConsent(
          {'requestedByUserId': 'ana', 'pendingUserIds': ['bilal']},
          me: 'cara',
          requesterKey: 'requestedByUserId',
        ),
        isFalse,
      );
    });
  });

  Future<bool?> openAndChoose(
    WidgetTester tester,
    Future<bool?> Function(BuildContext) open,
    String choice, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: platform),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await open(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice));
    await tester.pumpAndSettle();
    return result;
  }

  group('going live', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('the question names who asked and what it means ($platform)',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => askGoLive(ctx, 'Ana'),
                child: const Text('open'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Ana wants to go live.'), findsOneWidget);
        expect(
            find.text('Everyone on Aura could watch this call.'), findsOneWidget);
        expect(find.text('Stay private'), findsOneWidget);
        expect(find.text('Go live'), findsOneWidget);
      });
    }

    testWidgets('Go live accepts', (tester) async {
      expect(await openAndChoose(tester, (c) => askGoLive(c, 'Ana'), 'Go live'),
          isTrue);
    });

    testWidgets('Stay private declines', (tester) async {
      expect(
          await openAndChoose(
              tester, (c) => askGoLive(c, 'Ana'), 'Stay private'),
          isFalse);
    });
  });

  group('recording', () {
    testWidgets('the question names who asked; Allow recording allows',
        (tester) async {
      final r = await openAndChoose(
          tester, (c) => askRecording(c, 'Mia'), 'Allow recording');
      expect(r, isTrue);
    });

    testWidgets('someone arriving mid-recording is told it is running',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  askRecording(ctx, 'Mia', alreadyRecording: true),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Mia is recording this meeting.'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Allow recording'), findsOneWidget);
    });

    testWidgets('Leave is the other answer', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => askRecording(ctx, 'Mia'),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Mia wants to record this meeting.'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Allow recording'), findsOneWidget);
    });
  });

  testWidgets('a viewer whose live ended is told so, with a way back',
      (tester) async {
    var back = 0;
    await tester.pumpWidget(
        MaterialApp(home: LiveEndedView(onBack: () => back++)));
    expect(find.text('The live has ended.'), findsOneWidget);
    await tester.tap(find.text('Back'));
    expect(back, 1);
  });
}
