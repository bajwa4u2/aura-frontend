// Golden screenshots for [AuraMediaFrame]. Produces real PNG files at
// test/goldens/ that can be inspected to verify the visual contract.
//
// Run from aura_final/:
//   flutter test --update-goldens test/aura_media_frame_golden_test.dart
//
// The images use a synthetic colored RGBA placeholder rendered into the
// AuraMediaFrame via [Image.memory] wrapped in a public file URL — but
// since AuraMediaFrame's network path is hard to stub in tests, we use
// the error fallback as a stand-in for the *frame* contract: the
// outermost box (ClipRRect + AspectRatio + bounded width/height) is
// what matters for the "no overflow / consistent rhythm" requirement.
// To verify the IMAGE rendering itself you need to run the app and
// view a real post — that step is captured in the manual checklist.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/aura_media_frame.dart';
import 'package:aura/core/ui/aura_surface.dart';

class _Scenario {
  const _Scenario({
    required this.label,
    required this.mode,
    this.intrinsicWidth,
    this.intrinsicHeight,
  });
  final String label;
  final AuraMediaFrameMode mode;
  final int? intrinsicWidth;
  final int? intrinsicHeight;
}

const _scenarios = <_Scenario>[
  _Scenario(
    label: 'Feed · landscape 1920×1080',
    mode: AuraMediaFrameMode.feed,
    intrinsicWidth: 1920,
    intrinsicHeight: 1080,
  ),
  _Scenario(
    label: 'Feed · portrait 1080×1920 (text-heavy graphic)',
    mode: AuraMediaFrameMode.feed,
    intrinsicWidth: 1080,
    intrinsicHeight: 1920,
  ),
  _Scenario(
    label: 'Feed · square 1080×1080',
    mode: AuraMediaFrameMode.feed,
    intrinsicWidth: 1080,
    intrinsicHeight: 1080,
  ),
  _Scenario(
    label: 'Feed · panoramic 4000×1000',
    mode: AuraMediaFrameMode.feed,
    intrinsicWidth: 4000,
    intrinsicHeight: 1000,
  ),
  _Scenario(
    label: 'Feed · unknown dimensions',
    mode: AuraMediaFrameMode.feed,
  ),
  _Scenario(
    label: 'Detail · portrait 1080×1920',
    mode: AuraMediaFrameMode.detail,
    intrinsicWidth: 1080,
    intrinsicHeight: 1920,
  ),
  _Scenario(
    label: 'Detail · landscape 1920×1080',
    mode: AuraMediaFrameMode.detail,
    intrinsicWidth: 1920,
    intrinsicHeight: 1080,
  ),
  _Scenario(
    label: 'Thumbnail · square 1080×1080',
    mode: AuraMediaFrameMode.thumbnail,
    intrinsicWidth: 1080,
    intrinsicHeight: 1080,
  ),
];

Widget _galleryAt({
  required Size viewport,
  required Color background,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Theme(
      data: ThemeData(brightness: Brightness.light),
      child: Material(
        color: background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                for (final s in _scenarios) ...[
                  _ScenarioRow(scenario: s),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({required this.scenario});
  final _Scenario scenario;

  @override
  Widget build(BuildContext context) {
    final dims = scenario.intrinsicWidth != null
        ? '${scenario.intrinsicWidth}×${scenario.intrinsicHeight}'
        : '?×?';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  scenario.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(dims, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // The AuraMediaFrame itself. We pass an empty URL so the
        // frame's built-in error tile renders without touching
        // CachedNetworkImage's sqlite cache (which isn't available
        // in test environments). What we're inspecting is the FRAME
        // GEOMETRY — rounded corners, bounded width/height, aspect
        // decision, backdrop choice. A second-pass live screenshot
        // from a running app is the only way to validate the actual
        // photo rendering.
        AuraMediaFrame(
          url: '',
          intrinsicWidth: scenario.intrinsicWidth,
          intrinsicHeight: scenario.intrinsicHeight,
          mode: scenario.mode,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('AuraMediaFrame gallery · desktop viewport',
      (tester) async {
    const viewport = Size(1280, 2400);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _galleryAt(viewport: viewport, background: const Color(0xFFFAFAFC)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aura_media_frame_gallery_desktop.png'),
    );
  });

  testWidgets('AuraMediaFrame gallery · mobile narrow viewport',
      (tester) async {
    const viewport = Size(380, 2400);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _galleryAt(viewport: viewport, background: const Color(0xFFFAFAFC)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aura_media_frame_gallery_mobile.png'),
    );
  });
}
