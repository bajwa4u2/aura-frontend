import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/aura_space.dart';
import 'package:aura/core/ui/aura_surface.dart';
import 'package:aura/features/institutions/profile/institution_profile_screen.dart';
import 'package:aura/features/me/data/data_export_repository.dart';
import 'package:aura/features/me/presentation/data_export_screen.dart';
import 'package:aura/features/me/presentation/widgets/data_export_panel.dart';

/// Review screenshots of "Download my data" for the founder. Skipped unless
/// EXPORT_SHOTS=<dir> is set.
void main() {
  final shots = Platform.environment['EXPORT_SHOTS'];

  Future<ExportFile> never() async => throw UnimplementedError();

  DataExportPanel panel(DataExportPhase phase) => DataExportPanel(
        buttonLabel: 'Download my data',
        fetch: never,
        initialPhase: phase,
        initialFilename: 'aura-my-data-2026-10-27.json',
        initialRetryAt: DateTime(2026, 10, 28, 9, 41),
      );

  Future<void> pump(WidgetTester tester, Size size, GlobalKey key, Widget home) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AuraSurface.page,
            fontFamily: 'AuraSans',
            colorScheme: const ColorScheme.dark(
              primary: AuraSurface.accent,
              surface: AuraSurface.card,
              onSurface: AuraSurface.ink,
            ),
          ),
          home: Material(color: AuraSurface.page, child: home),
        ),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> save(WidgetTester tester, GlobalKey key, String name) async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.binding.runAsync(() async {
      final image = await b.toImage(pixelRatio: 2.0);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory(shots!).createSync(recursive: true);
    File('$shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  testWidgets('review screenshots', (tester) async {
    await _loadFonts();
    const sizes = [Size(1440, 900), Size(390, 844)];
    for (final size in sizes) {
      final w = size.width.toInt();
      final h = size.height.toInt();
      for (final (phase, name) in const [
        (DataExportPhase.ready, 'idle'),
        (DataExportPhase.saved, 'saved'),
        (DataExportPhase.onceADay, 'already_today'),
      ]) {
        final key = GlobalKey();
        await pump(tester, size, key, DataExportScreen(panel: panel(phase)));
        await save(tester, key, 'personal_${name}_${w}x$h');
      }
      final key = GlobalKey();
      await pump(
        tester,
        size,
        key,
        Scaffold(
          backgroundColor: AuraSurface.page,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(AuraSpace.s16),
                children: const [
                  InstitutionDataExportSection(institutionId: 'i1'),
                ],
              ),
            ),
          ),
        ),
      );
      await save(tester, key, 'institution_${w}x$h');
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: shots == null || shots.isEmpty);
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await family('AuraSerif', ['assets/fonts/SourceSerif4-500.ttf', 'assets/fonts/SourceSerif4-600.ttf']);
  await family('AuraSans', [
    for (final f in Directory('assets/fonts').listSync().whereType<File>())
      if (f.path.contains('PublicSans')) f.path,
  ]);
  final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await loader.load();
  }
}
