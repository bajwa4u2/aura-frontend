import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/app/not_found_screen.dart';
import 'package:aura/core/auth/session_providers.dart';

/// The page for an address Aura does not have (founder-approved, 2026-10-26).
/// Finders, not pixels. Set NOTFOUND_SHOTS=<dir> to also save PNGs for review.
void main() {
  GoRouter router() => GoRouter(
        initialLocation: '/zzz',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('PUBLIC HOME')),
          GoRoute(path: '/home', builder: (_, __) => const Text('MEMBER HOME')),
          GoRoute(path: '/discover', builder: (_, __) => const Text('DISCOVER')),
        ],
        errorBuilder: (_, state) => NotFoundScreen(address: state.uri.path),
      );

  Future<void> pumpAt(
    WidgetTester tester, {
    required bool signedIn,
    Size size = const Size(390, 844),
    double textScale = 1.0,
    TextDirection direction = TextDirection.ltr,
    GlobalKey? boundary,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Widget app = MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(textDirection: direction, child: child!),
      ),
    );
    if (boundary != null) app = RepaintBoundary(key: boundary, child: app);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isAuthedProvider.overrideWithValue(signedIn)],
        child: app,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says plainly the page is not here, with no developer text', (tester) async {
    await pumpAt(tester, signedIn: true);
    expect(find.text(NotFoundScreen.heading), findsOneWidget);
    expect(find.text(NotFoundScreen.explanation), findsOneWidget);
    expect(find.textContaining('Route not found'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.text('/zzz'), findsOneWidget); // quiet, so a person sees what they typed
  });

  testWidgets('signed in: home is the feed', (tester) async {
    await pumpAt(tester, signedIn: true);
    await tester.tap(find.text('Go to your feed'));
    await tester.pumpAndSettle();
    expect(find.text('MEMBER HOME'), findsOneWidget);
  });

  testWidgets('signed out: home is the public front door', (tester) async {
    await pumpAt(tester, signedIn: false);
    await tester.tap(find.text('Go to Aura'));
    await tester.pumpAndSettle();
    expect(find.text('PUBLIC HOME'), findsOneWidget);
  });

  testWidgets('explore discussions goes to discover', (tester) async {
    await pumpAt(tester, signedIn: true);
    await tester.tap(find.text('Explore discussions'));
    await tester.pumpAndSettle();
    expect(find.text('DISCOVER'), findsOneWidget);
  });

  testWidgets('fits every width, large text and right-to-left', (tester) async {
    for (final size in const [Size(320, 568), Size(390, 844), Size(1440, 900), Size(2560, 1440)]) {
      for (final scale in const [1.0, 1.75]) {
        for (final dir in TextDirection.values) {
          await pumpAt(tester, signedIn: true, size: size, textScale: scale, direction: dir);
          expect(tester.takeException(), isNull, reason: '$size x$scale $dir');
          expect(find.text(NotFoundScreen.heading), findsOneWidget);
        }
      }
    }
  });

  final shots = Platform.environment['NOTFOUND_SHOTS'];
  testWidgets('review screenshots', (tester) async {
    await _loadFonts();
    for (final size in const [Size(390, 844), Size(1440, 900)]) {
      final key = GlobalKey();
      await pumpAt(tester, signedIn: true, size: size, boundary: key);
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.binding.runAsync(() async {
        final image = await b.toImage(pixelRatio: 2.0);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      File('$shots/notfound_${size.width.toInt()}x${size.height.toInt()}.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
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
}
