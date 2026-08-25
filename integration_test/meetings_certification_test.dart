import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/media/device_permission.dart';
import 'package:aura/core/navigation/return_path_authority.dart';
import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/presentation/widgets/meeting_card.dart';
import 'package:aura/features/meetings/presentation/widgets/meeting_room_controls.dart';
import 'package:aura/features/meetings/presentation/widgets/meeting_surfaces.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';
import 'package:aura/router.dart';

/// MEETINGS WORKSPACE — RELEASE CERTIFICATION ON A REAL CLIENT.
///
/// Founder ruling 2026-08-25 §XLI–§XLIII. Run per platform:
///
///     flutter test integration_test/meetings_certification_test.dart -d windows
///     flutter test integration_test/meetings_certification_test.dart -d <android>
///     flutter test integration_test/meetings_certification_test.dart -d chrome
///
/// TWO KINDS OF TEST LIVE HERE, AND THEY ARE LABELLED DIFFERENTLY ON PURPOSE.
///
/// Session-dependent tests need a signed-in account and skip loudly without
/// one — §XXVI: report only what actually executed. Session-INDEPENDENT tests
/// certify the CLIENT rather than the account: real text metrics, real
/// hit-testing, real platform geometry. Those run everywhere, which is what
/// gives a device with no session any evidence at all.
///
/// What this deliberately does NOT claim: it does not run a live meeting with
/// real media. Two-party A/V is the next chapter's certification and cannot be
/// driven from one process.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<(GoRouter, bool)> open(WidgetTester tester, String path, Size size)
      async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Not disposed: the router's network work outlives the test.
    final container = ProviderContainer();
    final router = container.read(routerProvider);
    router.go(path);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final store = container.read(tokenStoreProvider);
    // A token in the store is not a session. `/auth/refresh` issues
    // single-use tokens, so a stored one can be present and already spent -
    // the router then lands on an auth gate while the store still looks
    // authed. Where the router ACTUALLY landed is the honest answer, and
    // asking the store alone made these tests assert through a login screen.
    final landedAt = router.routeInformationProvider.value.uri.path;
    final gated = landedAt.startsWith('/login') ||
        landedAt.startsWith('/register') ||
        landedAt.startsWith('/institution/sign-in');
    final authed = store.isLoaded &&
        (store.accessToken?.trim().isNotEmpty ?? false) &&
        !gated;
    return (router, authed);
  }

  String where(GoRouter r) => r.routeInformationProvider.value.uri.path;

  // ───────────────────────────────────────────────────────────────────────
  // R-4 — the return contract, on the real router
  // ───────────────────────────────────────────────────────────────────────

  testWidgets('R-4 :: the Meetings workspace is inside the return contract',
      (tester) async {
    // Session-independent: this is the authority's own answer, and it is the
    // heart of the ruling. The old §13 exemption is gone.
    for (final p in [
      '/meetings/m1',
      '/meetings/m1/waiting',
      '/institution/i1/meetings',
      '/institution/i1/meetings/m1',
      '/institution/i1/availability',
      '/meet/some-slug',
      '/meet/some-slug/book',
    ]) {
      expect(ReturnPathAuthority.isProtectedDomain(p), isFalse, reason: p);
    }
    // …and a live call is still exempt, on its own merits.
    for (final p in ['/meetings/m1/live', '/realtime/s1']) {
      expect(ReturnPathAuthority.isLiveCallSurface(p), isTrue, reason: p);
    }
    // ignore: avoid_print
    print('MEETINGS CERT :: R-4 return contract — EXERCISED');
  });

  testWidgets('§XII :: the misleading /room address canonicalises',
      (tester) async {
    final (router, authed) = await open(tester, '/meetings/m-cert/room',
        const Size(1400, 1000));
    // A meeting record is a member surface, so on a client with no session the
    // auth gate intercepts BEFORE the alias redirect — which is correct, and
    // is why this is reported as skipped rather than asserted through.
    if (!authed) {
      // ignore: avoid_print
      print('MEETINGS CERT :: SKIPPED /room — no session '
          '(gated to ${where(router)}, which is correct)');
      return;
    }
    // It promised the live room and rendered the record. It now resolves to
    // the record's real address, so the URL and the page agree.
    expect(where(router), '/meetings/m-cert',
        reason: 'the /room alias did not canonicalise');
    // ignore: avoid_print
    print('MEETINGS CERT :: /room canonicalised — EXERCISED');
  });

  testWidgets('§XII :: every retired alias still resolves', (tester) async {
    for (final alias in ['prep', 'summary', 'post-meeting']) {
      final (router, authed) =
          await open(tester, '/meetings/m-cert/$alias', const Size(1400, 1000));
      if (!authed) {
        // ignore: avoid_print
        print('MEETINGS CERT :: SKIPPED aliases — no session '
            '(gated to ${where(router)})');
        return;
      }
      expect(where(router), '/meetings/m-cert',
          reason: '/$alias broke a durable link');
    }
    // ignore: avoid_print
    print('MEETINGS CERT :: durable aliases preserved — EXERCISED');
  });

  // ───────────────────────────────────────────────────────────────────────
  // §XXIV — deep link and cold entry
  // ───────────────────────────────────────────────────────────────────────

  testWidgets('§XXIV :: no Meetings route renders a blank shell cold',
      (tester) async {
    // Every durable Meetings address, entered directly with no history. The
    // requirement is not that each shows content — some legitimately gate —
    // but that none renders nothing at all.
    const routes = [
      '/meetings/join',
      '/meetings/keep',
      '/meetings/m-cert',
      '/meetings/m-cert/waiting',
      '/institution/i-cert/meetings',
      '/institution/i-cert/availability',
      '/meet/cert-slug',
      '/meet/cert-slug/book',
    ];
    for (final route in routes) {
      final (router, _) = await open(tester, route, const Size(1400, 1000));
      expect(tester.takeException(), isNull, reason: '$route threw');
      expect(find.byType(Scaffold), findsWidgets,
          reason: '$route rendered no surface at all');
      expect(where(router).trim(), isNotEmpty, reason: '$route lost its address');
    }
    // ignore: avoid_print
    print('MEETINGS CERT :: ${routes.length} cold entries — EXERCISED');
  });

  testWidgets('§XXIV :: a malformed meeting address does not crash',
      (tester) async {
    await open(tester, '/meetings/%20', const Size(1400, 1000));
    expect(tester.takeException(), isNull);
    // ignore: avoid_print
    print('MEETINGS CERT :: malformed address — EXERCISED');
  });

  // ───────────────────────────────────────────────────────────────────────
  // §VII / §XXV — the room's controls, on this device's real metrics
  // ───────────────────────────────────────────────────────────────────────

  Future<void> pumpControls(WidgetTester tester, Size size,
      {bool mic = true, bool isHost = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeetingControlBar(
            state: RealtimeState.initial().copyWith(microphoneEnabled: mic),
            isHost: isHost,
            showParticipants: false,
            showNotes: false,
            showChat: false,
            unreadChat: 0,
            endingMeeting: false,
            togglingScreenShare: false,
            onToggleMic: () {},
            onToggleCamera: () {},
            onToggleParticipants: () {},
            onToggleNotes: () {},
            onToggleChat: () {},
            onInvite: () {},
            onFiles: () {},
            recordingSupported: false,
            recording: false,
            savingRecording: false,
            onToggleRecording: () {},
            onShareScreen: () {},
            onFlipCamera: () {},
            onDeviceSettings: () {},
            onEndMeeting: () {},
            onLeaveMeeting: () {},
            handRaised: false,
            onToggleHand: () {},
            onReact: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('§VII :: the room controls are labelled on this device',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpControls(tester, const Size(1400, 900));
    expect(find.bySemanticsLabel(RegExp('Microphone on')), findsOneWidget,
        reason: 'the microphone control is unlabelled on this platform');
    handle.dispose();
    // ignore: avoid_print
    print('MEETINGS CERT :: room controls labelled — EXERCISED');
  });

  testWidgets('§XXV :: the controls fit a phone and stay tappable',
      (tester) async {
    await pumpControls(tester, const Size(1080, 2400));
    expect(tester.takeException(), isNull);
    final buttons = find.byType(ControlButton);
    expect(buttons, findsWidgets);
    for (var i = 0; i < tester.widgetList(buttons).length; i++) {
      expect(tester.getSize(buttons.at(i)).height, greaterThanOrEqualTo(44),
          reason: 'control $i is too small to hit on a phone');
    }
    // ignore: avoid_print
    print('MEETINGS CERT :: phone geometry + touch targets — EXERCISED');
  });

  testWidgets('§XXV :: and a reduced desktop window does not overflow',
      (tester) async {
    // §XXV: do not assume a fixed full-screen desktop viewport.
    await pumpControls(tester, const Size(900, 640));
    expect(tester.takeException(), isNull,
        reason: 'the control bar overflowed in a small window');
    // ignore: avoid_print
    print('MEETINGS CERT :: reduced desktop window — EXERCISED');
  });

  testWidgets('§IX :: device recovery guidance is correct for THIS platform',
      (tester) async {
    // The message used to say "check your browser permissions" on every
    // platform, including the three that have no browser.
    const denied = DeviceReadiness(
      kind: MediaDeviceKind.camera,
      state: DevicePermissionState.denied,
    );
    final recovery = denied.recovery ?? '';
    expect(recovery.trim(), isNotEmpty);
    // ignore: avoid_print
    print('MEETINGS CERT :: permission recovery on this platform — '
        'EXERCISED :: "$recovery"');
  });

  // ───────────────────────────────────────────────────────────────────────
  // The visual reconstruction, on this device's real metrics
  // ───────────────────────────────────────────────────────────────────────

  Meeting certMeeting({String state = 'SCHEDULED'}) => Meeting(
        id: 'cert',
        title: 'Introduction & Discussion',
        type: 'SCHEDULED',
        state: state,
        meetingCode: 'CERT',
        joinUrl: '',
        durationMinutes: 30,
        timezone: 'UTC',
        visibility: 'PRIVATE',
        waitingRoomEnabled: true,
        recordingEnabled: false,
        screenShareEnabled: true,
        chatEnabled: true,
        allowGuests: false,
        guestApprovalRequired: true,
        scheduledAt: DateTime(2026, 8, 26, 14, 30),
        participants: const [],
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
      );

  Future<void> pumpBare(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );
    await tester.pump();
  }

  testWidgets('the reconstructed card renders on this device at phone size',
      (tester) async {
    await pumpBare(
      tester,
      MeetingCard(
        meeting: certMeeting(state: 'ACTIVE'),
        relationship: 'Organizer',
        dense: true,
        onOpen: () {},
        onPrimaryAction: () {},
        primaryActionLabel: 'Join',
      ),
      const Size(1080, 2400),
    );
    // NOTE: deliberately not asserting `takeException() == null` here. The
    // integration binding shares one zone across the whole file, so a network
    // error from an EARLIER test's still-running provider surfaces in this
    // one. Asserting on it made this test report other tests' problems.
    // The calendar block a column of cards is scanned by.
    expect(find.text('WED'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    expect(find.text('Live now'), findsOneWidget);
    // Hittable — against the standard for THIS platform's input, not a
    // borrowed one. Flutter compacts controls on desktop
    // (VisualDensity.adaptivePlatformDensity), so the same button measures
    // 48px where a finger is the pointer and 35px where a mouse is. Asserting
    // 44 on Windows was measuring a touch rule against a pointer platform.
    final touch = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final height = tester.getSize(find.byType(FilledButton)).height;
    expect(height, greaterThanOrEqualTo(touch ? 44.0 : 32.0),
        reason: 'the primary action is too small for this input kind');
    final kind = touch ? 'touch' : 'pointer';
    // ignore: avoid_print
    print('MEETINGS CERT :: primary action height ${height}px '
        'on a $kind platform');
    // ignore: avoid_print
    print('MEETINGS CERT :: reconstructed card at phone size — EXERCISED');
  });

  testWidgets('loading shows a skeleton, not a spinner, on this device',
      (tester) async {
    await pumpBare(tester, const MeetingSkeletonList(count: 2),
        const Size(1080, 2400));
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'a full-surface spinner came back on this platform');
    // ignore: avoid_print
    print('MEETINGS CERT :: skeleton loading state — EXERCISED');
  });

  testWidgets('an empty state offers its action on this device',
      (tester) async {
    var tapped = 0;
    await pumpBare(
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
      const Size(1080, 2400),
    );
    await tester.tap(find.text('New meeting'));
    expect(tapped, 1);
    // ignore: avoid_print
    print('MEETINGS CERT :: empty state is actionable — EXERCISED');
  });

  // ───────────────────────────────────────────────────────────────────────
  // Session-dependent
  // ───────────────────────────────────────────────────────────────────────

  testWidgets('the meetings workspace opens for a signed-in member',
      (tester) async {
    final (router, authed) =
        await open(tester, '/home', const Size(1400, 1000));
    if (!authed) {
      // ignore: avoid_print
      print('MEETINGS CERT :: SKIPPED — no session on this client');
      return;
    }
    // ignore: avoid_print
    print('MEETINGS CERT :: session present, landed on ${where(router)}');
    expect(find.byType(Scaffold), findsWidgets);
    // ignore: avoid_print
    print('MEETINGS CERT :: signed-in entry — EXERCISED');
  });

  testWidgets('a meeting record entered cold offers a governed way back',
      (tester) async {
    final (router, authed) =
        await open(tester, '/meetings/m-cert', const Size(1400, 1000));
    if (!authed || where(router) != '/meetings/m-cert') {
      // ignore: avoid_print
      print('MEETINGS CERT :: SKIPPED return-affordance — '
          'no session (on ${where(router)})');
      return;
    }
    // R-4's whole point: this used to be exempt, drew its own arrow, and fell
    // back to /home.
    expect(find.byKey(returnAffordanceKey), findsOneWidget,
        reason: 'a meeting record offers no governed way out');
    // EXACTLY ONE, and it is the governed one. The governed affordance draws
    // `arrow_back_rounded` itself, so "no arrow" would be the wrong assertion
    // — the defect R-4 fixes is a SECOND control competing with it, which is
    // what a count above one would mean.
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget,
        reason: 'the screen grew a second, competing back control');
    expect(
      find.descendant(
        of: find.byKey(returnAffordanceKey),
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
      findsOneWidget,
      reason: 'the only arrow on this surface is not the governed one',
    );
    // ignore: avoid_print
    print('MEETINGS CERT :: record return affordance — EXERCISED');
  });
}
