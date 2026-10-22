import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/compliance/report_repository.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/presentation/widgets/live_safety_menu.dart';
import 'package:aura/features/realtime/presentation/widgets/realtime_participant_list.dart';

/// LIVE AUDIENCE SAFETY (founder-approved design, 22 Oct 2026; store
/// guideline 1.2): a public live can be reported, and every speaker can be
/// reported or blocked.
void main() {
  RealtimeParticipant person(String id, String name) => RealtimeParticipant(
        id: id,
        userId: id,
        runtimeDeviceId: null,
        role: RealtimeParticipantRole.participant,
        joinState: 'JOINED',
        isPresent: true,
        audioOn: true,
        videoOn: true,
        screenOn: false,
        displayName: name,
        handle: null,
        avatarUrl: null,
        displayRole: null,
        institutionName: null,
        institutionHandle: null,
        institutionRole: null,
        institutionTitle: null,
        joinedAt: null,
        leftAt: null,
      );

  Future<void> openMenu(WidgetTester tester, {RealtimeParticipant? speaker}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showLiveSafetyMenu(
                  context,
                  ref,
                  sessionId: 's1',
                  speaker: speaker,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the live itself can be reported', (tester) async {
    await openMenu(tester);
    expect(find.text('Report this live'), findsOneWidget);
    expect(find.textContaining('Block'), findsNothing);
  });

  testWidgets('a speaker can be reported and blocked by name', (tester) async {
    await openMenu(tester, speaker: person('u2', 'Ana'));
    expect(find.text('Report Ana'), findsOneWidget);
    expect(find.text('Block Ana'), findsOneWidget);
  });

  test('the live report target goes to the server as LIVE_SESSION', () {
    expect(ReportTargetType.liveSession.wire, 'LIVE_SESSION');
  });

  testWidgets('on a live, every other speaker has a "More" for safety',
      (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RealtimeParticipantList(
            participants: [person('me', 'Me'), person('u2', 'Ana')],
            session: null,
            canModerate: false,
            currentUserId: 'me',
            remoteRenderers: const {},
            onRemove: (_) {},
            onSafety: (p) => tapped.add(p.userId),
          ),
        ),
      ),
    ));
    expect(find.byTooltip('More'), findsOneWidget,
        reason: 'one for Ana, none for yourself');
    await tester.tap(find.byTooltip('More'));
    expect(tapped, ['u2']);
  });

  testWidgets('off a live there is no safety "More"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RealtimeParticipantList(
            participants: [person('me', 'Me'), person('u2', 'Ana')],
            session: null,
            canModerate: false,
            currentUserId: 'me',
            remoteRenderers: const {},
            onRemove: (_) {},
          ),
        ),
      ),
    ));
    expect(find.byTooltip('More'), findsNothing);
  });
}
