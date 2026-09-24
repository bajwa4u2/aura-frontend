import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/presentation/meeting_stage.dart';

/// ACTUAL FRAMES, NOT ONLY GEOMETRY.
///
/// The founder's instruction was explicit: inspect rendered frames, not only
/// widget or layout tests. This paints the stage at real viewport sizes and
/// writes the images to `build/meeting_frames/` so a human can look at them.
///
/// It asserts the one thing a picture can be wrong about on its own — that
/// something was actually painted — and leaves judgement of the composition
/// to the eye it is written for.
void main() {
  final outDir = Directory('build/meeting_frames');

  setUpAll(() {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
  });

  Future<void> capture(
    WidgetTester tester, {
    required String name,
    required int people,
    required Size viewport,
    bool presenting = false,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tiles = [
      for (var i = 0; i < people; i++)
        StageTile(
          key: 'p$i',
          label: i == 0 ? 'M S Bajwa' : 'Person $i',
          isLocal: i == 0,
          micOn: i != 1,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF030712),
          body: RepaintBoundary(
            key: const ValueKey('stage'),
            child: MeetingStage(
              tiles: tiles,
              // A presentation is represented by its composition; the shared
              // renderer itself needs a platform view, which a widget test has
              // no way to provide. The filmstrip and the dominance of the
              // shared surface are what this frame is for.
              presenterLabel: presenting ? 'M S Bajwa' : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('stage')),
    );
    final bytes = await tester.binding.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    expect(bytes, isNotNull, reason: 'the stage painted nothing');
    final data = bytes!.buffer.asUint8List();
    expect(data.length, greaterThan(2000), reason: 'an empty frame');
    File('${outDir.path}/$name.png').writeAsBytesSync(data);
  }

  const desktop = Size(1600, 780);
  const laptop = Size(1280, 640);
  const phone = Size(390, 740);

  testWidgets('one participant, desktop', (t) =>
      capture(t, name: '01-one-desktop', people: 1, viewport: desktop));
  testWidgets('two participants, desktop', (t) =>
      capture(t, name: '02-two-desktop', people: 2, viewport: desktop));
  testWidgets('THREE participants, desktop — the reported frame', (t) =>
      capture(t, name: '03-three-desktop', people: 3, viewport: desktop));
  testWidgets('four participants, desktop', (t) =>
      capture(t, name: '04-four-desktop', people: 4, viewport: desktop));
  testWidgets('five participants, desktop', (t) =>
      capture(t, name: '05-five-desktop', people: 5, viewport: desktop));
  testWidgets('three participants, laptop', (t) =>
      capture(t, name: '06-three-laptop', people: 3, viewport: laptop));
  testWidgets('three participants, phone portrait', (t) =>
      capture(t, name: '07-three-phone', people: 3, viewport: phone));
  testWidgets('two participants, phone portrait', (t) =>
      capture(t, name: '08-two-phone', people: 2, viewport: phone));
}
