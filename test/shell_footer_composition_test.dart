// Guards the public footer's desktop composition. The footer must compose
// into its side-by-side (brand left / link columns right) layout at the
// width the public home page actually gives it — the page is wrapped in
// AuraScaffold's default 920 px container, so the footer's own inner width
// there is ~880 px. A regression that re-pins the footer's wide-breakpoint
// at/above that width drops the footer back into its stacked layout, which
// leaves the right of the full-bleed dark surface empty (the "void" bug).
//
// We assert on geometry, not goldens: in the wide layout the brand block and
// the first link column sit on the SAME row (overlapping vertically) with the
// brand to the left; in the stacked layout the columns sit BELOW the brand.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/app/shell/shell_shared.dart';
import 'package:aura/core/ui/aura_responsive.dart';

/// Pumps the footer inside the same container the public home gives it:
/// a centered ConstrainedBox at AuraScaffold's default page width.
Future<void> _pumpFooter(WidgetTester tester, double viewportWidth) async {
  tester.view.physicalSize = Size(viewportWidth, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Minimal router so InkWell/GestureDetector callbacks resolve a context.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(
            // 920 = AuraScaffold._defaultMaxWidth, the public home container.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: const SizedBox(
                  width: double.infinity,
                  child: ShellFooter(),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('footer goes wide at the public home width (~880 px inner)', (
    tester,
  ) async {
    await _pumpFooter(tester, 1440);

    // The brand wordmark logo sits in the brand block; "MISSION" is the
    // first link in the first link column.
    final brand = tester.getRect(
      find.text(
        'Aura is institution operating infrastructure. Institutions run their '
        'public and member-facing life on one verified identity and one '
        'accountable record.',
      ),
    );
    final firstColLabel = tester.getRect(find.text('AURA'));

    // Wide layout: the link columns sit to the RIGHT of the brand block. In
    // the stacked layout they instead drop below it at the left edge, so this
    // horizontal relationship cleanly distinguishes the two.
    expect(
      firstColLabel.left,
      greaterThan(brand.right),
      reason: 'link columns should be to the right of the brand block',
    );
  });

  testWidgets('footer stacks on mobile width', (tester) async {
    await _pumpFooter(tester, 400);

    final brand = tester.getRect(
      find.text(
        'Aura is institution operating infrastructure. Institutions run their '
        'public and member-facing life on one verified identity and one '
        'accountable record.',
      ),
    );
    final firstColLabel = tester.getRect(find.text('AURA'));

    // Stacked layout: the link columns drop BELOW the brand block.
    expect(
      firstColLabel.top,
      greaterThan(brand.bottom),
      reason: 'on mobile the columns must stack below the brand',
    );
  });

  test('footer container width matches the canonical public surface', () {
    // Instruction #3: the footer shares the surface sections content width.
    expect(ShellFooter.maxWidth, kHeroWidth);
  });
}
