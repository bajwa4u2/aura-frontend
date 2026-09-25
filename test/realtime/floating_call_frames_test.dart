import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/presentation/widgets/floating_call_card.dart';
import 'package:aura/features/realtime/presentation/widgets/floating_call_layout.dart';

/// ACTUAL FRAMES OF THE MINIMISED CALL, NOT ONLY GEOMETRY.
///
/// Founder, 2026-09-24: *"pip is odd and ugly its same for the audio and
/// video"* — a judgement about how something LOOKS, which no assertion can
/// make on his behalf. So this paints every composition and writes the images
/// to `build/floating_call_frames/` for him to look at, and asserts only the
/// things a picture can be objectively wrong about:
///
///   * that something was painted at all;
///   * that an audio call and a video call are not the same size;
///   * that the controls are where a thumb can reach them.
void main() {
  final outDir = Directory('build/floating_call_frames');

  setUpAll(() {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
  });

  List<RealtimeParticipant> people(int n) => [
        for (var i = 0; i < n; i++)
          RealtimeParticipant(
            id: 'p$i',
            userId: 'u$i',
            runtimeDeviceId: 'd$i',
            role: RealtimeParticipantRole.participant,
            joinState: 'JOINED',
            isPresent: true,
            audioOn: true,
            videoOn: true,
            screenOn: false,
            displayName: i == 0 ? 'M S Bajwa' : 'Iffat S. Chaudhry',
            handle: i == 0 ? 'msbajwa' : 'iffat',
            avatarUrl: null,
            displayRole: null,
            institutionName: null,
            institutionHandle: null,
            institutionRole: null,
            institutionTitle: null,
            joinedAt: null,
            leftAt: null,
          ),
      ];

  /// A stand-in for the remote camera. The card takes a WIDGET, so a frame can
  /// be painted without WebRTC — which is the whole reason it was extracted.
  Widget stubPicture() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B3A55), Color(0xFF6B4E7D)],
          ),
        ),
        child: Center(
          child: Icon(Icons.person, size: 64, color: Color(0x55FFFFFF)),
        ),
      );

  Future<Size> capture(
    WidgetTester tester, {
    required String name,
    required FloatingCallComposition composition,
    required bool isVideo,
    bool micOn = true,
    bool cameraOn = true,
    bool joinedHere = true,
    int participants = 2,
    String? remoteName = 'Iffat S. Chaudhry',
    bool withEnd = true,
  }) async {
    tester.view.physicalSize = const Size(420, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0A1120),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: FloatingCallCard(
                composition: composition,
                isVideo: isVideo,
                micOn: micOn,
                cameraOn: cameraOn,
                participants: people(participants),
                startedAt: DateTime.now().subtract(const Duration(minutes: 7, seconds: 12)),
                joinedHere: joinedHere,
                remoteName: remoteName,
                onReturn: () {},
                onEnd: withEnd ? () {} : null,
                isEnding: false,
                onPanUpdate: (_) {},
                picture: floatingCallShowsPicture(composition) ? stubPicture() : null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    // RASTERISING NEEDS THE REAL EVENT LOOP.
    //
    // `toImage` completes on the engine's clock, not the test binding's fake
    // one, and the card runs a one-second ticker that keeps fake time from
    // idling. Awaited directly, the two deadlock: the suite writes a frame or
    // two and then hangs rather than failing. `runAsync` is what the meetings
    // stage frames test already does, for the same reason.
    final png = await tester.binding.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    expect(png, isNotNull, reason: '$name painted nothing');
    File('${outDir.path}/$name.png').writeAsBytesSync(
      png!.buffer.asUint8List(),
    );

    // A blank card would still write a file, so prove ink was laid down.
    expect(png.lengthInBytes, greaterThan(2000),
        reason: '$name looks empty — nothing was painted');

    // The tree is left standing: the callers that measure touch targets go on
    // to query it.
    return tester.getSize(find.byType(FloatingCallCard));
  }

  testWidgets('a video call with a picture IS the picture', (tester) async {
    final size = await capture(
      tester,
      name: '01-video-with-picture',
      composition: FloatingCallComposition.picture,
      isVideo: true,
    );
    expect(size, floatingCallSize(FloatingCallComposition.picture));
  });

  testWidgets('a video call with the mic muted says so, once', (tester) async {
    await capture(
      tester,
      name: '02-video-muted',
      composition: FloatingCallComposition.picture,
      isVideo: true,
      micOn: false,
    );
  });

  testWidgets('an audio call is a short bar, not a tall card', (tester) async {
    final size = await capture(
      tester,
      name: '03-audio-bar',
      composition: FloatingCallComposition.bar,
      isVideo: false,
    );
    expect(size, floatingCallSize(FloatingCallComposition.bar));
  });

  testWidgets('a video call before any picture arrives is also a bar',
      (tester) async {
    // No black 16:9 well while the far end's camera is off or still starting.
    await capture(
      tester,
      name: '04-video-no-picture-yet',
      composition: FloatingCallComposition.bar,
      isVideo: true,
      cameraOn: false,
    );
  });

  testWidgets('a call running in another tab offers no way to end it',
      (tester) async {
    await capture(
      tester,
      name: '05-passive-other-tab',
      composition: FloatingCallComposition.bar,
      isVideo: false,
      joinedHere: false,
      participants: 0,
      remoteName: null,
      withEnd: false,
    );
  });

  testWidgets('the two compositions are not the same object', (tester) async {
    final picture = floatingCallSize(FloatingCallComposition.picture);
    final bar = floatingCallSize(FloatingCallComposition.bar);
    expect(bar.height, lessThan(picture.height * 0.6));
  });

  group('C-4 — the controls are reachable by a thumb', () {
    for (final composition in FloatingCallComposition.values) {
      testWidgets('in the $composition composition', (tester) async {
        await capture(
          tester,
          name: '06-targets-${composition.name}',
          composition: composition,
          isVideo: composition == FloatingCallComposition.picture,
        );

        // THE MEASUREMENT THAT FOUND THE FAULT.
        //
        // The control this replaced painted and answered across about 21
        // logical pixels of height. Measuring the RENDERED box is the only
        // check that would have caught it — the old widget tree looked
        // perfectly reasonable, and a mouse hit it every single time.
        final controls = find.byType(Semantics).evaluate().where((e) {
          final w = e.widget as Semantics;
          return w.properties.button == true;
        });
        expect(controls, isNotEmpty, reason: 'no controls rendered at all');

        for (final element in controls) {
          final box = element.renderObject! as RenderBox;
          expect(box.size.width, greaterThanOrEqualTo(kFloatingControlTapTarget),
              reason: 'a control is narrower than a fingertip');
          expect(box.size.height, greaterThanOrEqualTo(kFloatingControlTapTarget),
              reason: 'a control is shorter than a fingertip');
        }
      });
    }
  });

  testWidgets('tapping Return is answered anywhere in its target',
      (tester) async {
    var returns = 0;
    tester.view.physicalSize = const Size(420, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: FloatingCallCard(
              composition: FloatingCallComposition.bar,
              isVideo: false,
              micOn: true,
              cameraOn: false,
              participants: people(2),
              startedAt: DateTime.now(),
              joinedHere: true,
              remoteName: 'Iffat S. Chaudhry',
              onReturn: () => returns++,
              onEnd: () {},
              isEnding: false,
              onPanUpdate: (_) {},
            ),
          ),
        ),
      ),
    );

    final target = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Return to call',
    );
    expect(target, findsOneWidget);
    final rect = tester.getRect(target);

    // The painted disc is 32px inside a 48px target. A press in the slack —
    // which is where a thumb aiming at a small mark actually lands — must be
    // answered, not swallowed. That is what `HitTestBehavior.opaque` buys.
    await tester.tapAt(rect.topLeft + const Offset(4, 4));
    await tester.pump();
    expect(returns, 1, reason: 'the transparent slack swallowed the press');

    await tester.tapAt(rect.center);
    await tester.pump();
    expect(returns, 2);
  });

  testWidgets('no yellow fallback underline when mounted WITHOUT a Material',
      (tester) async {
    // THE MOUNT THE PRODUCT ACTUALLY USES.
    //
    // `AuraIncomingLiveLayer` puts this card in a bare `Stack` beside the
    // app's child — no Scaffold, no Material. Flutter answers that with
    // `DefaultTextStyle.fallback()`, whose decoration is a YELLOW DOUBLE
    // UNDERLINE, and our styles inherit it because they set colour and weight
    // and never `decoration`.
    //
    // Founder-observed on a live call: the elapsed time reading `02:39`
    // underlined in yellow over the video.
    //
    // Every other test in this file renders inside a `Scaffold`, which
    // PROVIDES a Material — so they were all kinder than the real mount and
    // none of them could see this. This one deliberately is not.
    tester.view.physicalSize = const Size(420, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            const SizedBox.expand(),
            Center(
              child: FloatingCallCard(
                composition: FloatingCallComposition.bar,
                isVideo: false,
                micOn: true,
                cameraOn: false,
                participants: people(2),
                startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
                joinedHere: true,
                remoteName: 'Iffat S. Chaudhry',
                onReturn: () {},
                onEnd: () {},
                isEnding: false,
                onPanUpdate: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));

    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts, isNotEmpty, reason: 'the card rendered no text at all');

    for (final t in texts) {
      final element = find.text(t.data ?? '').evaluate().isEmpty
          ? null
          : find.text(t.data ?? '').evaluate().first;
      if (element == null) continue;
      final resolved = DefaultTextStyle.of(element).style.merge(t.style);
      expect(
        resolved.decoration ?? TextDecoration.none,
        TextDecoration.none,
        reason: 'text "\${t.data}" carries a decoration it never asked for — '
            'the card has lost its Material ancestor again',
      );
    }
  });

  testWidgets('a press on the controls does NOT drag the card', (tester) async {
    // The other half of C-4: the drag surface used to cover the buttons, so a
    // finger that drifted while pressing either did nothing or slid the card
    // away. The controls now sit outside it.
    var dragged = 0;
    var returns = 0;
    tester.view.physicalSize = const Size(420, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: FloatingCallCard(
              composition: FloatingCallComposition.bar,
              isVideo: false,
              micOn: true,
              cameraOn: false,
              participants: people(2),
              startedAt: DateTime.now(),
              joinedHere: true,
              remoteName: 'Iffat S. Chaudhry',
              onReturn: () => returns++,
              onEnd: () {},
              isEnding: false,
              onPanUpdate: (_) => dragged++,
            ),
          ),
        ),
      ),
    );

    final target = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Return to call',
    );

    // A firm drag starting on the Return control moves nothing.
    await tester.dragFrom(tester.getCenter(target), const Offset(60, 40));
    await tester.pump();
    expect(dragged, 0,
        reason: 'the control is inside the drag surface again — this is C-4');

    // The card's informational half still drags.
    final label = find.text('Iffat S. Chaudhry');
    expect(label, findsOneWidget);
    await tester.dragFrom(tester.getCenter(label), const Offset(60, 40));
    await tester.pump();
    expect(dragged, greaterThan(0), reason: 'the card can no longer be moved');

    expect(returns, 0, reason: 'a drag must not read as a tap');
  });
}
