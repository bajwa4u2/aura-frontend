// The PDF viewer moved from Syncfusion 29.2.11 to 33.2.13 (2026-10-21) so
// the Android build could move to AGP 9. Aura's one use is SfPdfViewer.asset
// behind PdfViewerScreen; this mounts it with the asset the app ships and
// keeps the upgrade from breaking the screen silently. Rendering pages needs
// the native PDF engine, which a widget test does not have.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:aura/core/ui/pdf_viewer_screen.dart';

void main() {
  testWidgets('PdfViewerScreen mounts the Syncfusion viewer on a shipped PDF',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: PdfViewerScreen(
          title: 'Investor deck',
          assetPath: 'assets/investor/Aura_Platform_Investor_Deck_2026.pdf',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Investor deck'), findsOneWidget);
    expect(find.byType(SfPdfViewer), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
