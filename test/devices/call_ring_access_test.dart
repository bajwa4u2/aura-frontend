import 'dart:io';
import 'dart:ui' as ui;

import 'package:aura/features/devices/presentation/call_ring_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CALLS THAT CANNOT RING ON THE LOCK SCREEN ARE SAID, AND FIXABLE.
///
/// Galaxy S24, 1.7.0 (49) from Play, 2026-10-28: full-screen alerts were off,
/// so a call to the locked phone was only a notification. Only the person can
/// turn the setting on; these pin that Aura asks, once, and keeps a card on
/// "Your devices" for as long as it stays off.
///
///   CALL_RING_SHOTS=build/call_ring_shots flutter test test/devices/call_ring_access_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Platform.environment['CALL_RING_SHOTS'] ?? '';

  setUpAll(_loadFonts);

  late bool allowed;
  late int opened;

  CallRingAccess access({bool applies = true}) => CallRingAccess(
        applies: applies,
        allowed: () async => allowed,
        openSettings: () async {
          opened++;
          return true;
        },
      );

  setUp(() {
    allowed = false;
    opened = 0;
    resetCallRingAskForTest();
    SharedPreferences.setMockInitialValues({});
  });

  Widget app(Widget child, CallRingAccess a, GlobalKey key) => ProviderScope(
        overrides: [callRingAccessProvider.overrideWithValue(a)],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: Brightness.dark, fontFamily: 'AuraSans'),
            home: Scaffold(backgroundColor: const Color(0xFF0B0E13), body: child),
          ),
        ),
      );

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    if (outDir.isEmpty) return;
    Directory(outDir).createSync(recursive: true);
    final boundary = tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final png = await tester.binding.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    File('$outDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  testWidgets('blocked: asks once at launch; Turn on opens the setting',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
        app(const CallRingAsk(child: SizedBox.expand()), access(), key));
    await tester.pumpAndSettle();
    expect(find.text('Let calls ring on your lock screen'), findsOneWidget);
    await shot(tester, key, 'sheet_w390');

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('Not now keeps it away for the snooze, and once per run',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
        app(const CallRingAsk(child: SizedBox.expand()), access(), key));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(opened, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('aura_call_ring_ask_snoozed_at'), isNotNull);

    // A new run inside the snooze does not ask.
    resetCallRingAskForTest();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
        app(const CallRingAsk(child: SizedBox.expand()), access(), key));
    await tester.pumpAndSettle();
    expect(find.text('Let calls ring on your lock screen'), findsNothing);
  });

  testWidgets('allowed, or not Android: never asks', (tester) async {
    final key = GlobalKey();
    allowed = true;
    await tester.pumpWidget(
        app(const CallRingAsk(child: SizedBox.expand()), access(), key));
    await tester.pumpAndSettle();
    expect(find.text('Let calls ring on your lock screen'), findsNothing);

    allowed = false;
    resetCallRingAskForTest();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(const CallRingAsk(child: SizedBox.expand()),
        access(applies: false), key));
    await tester.pumpAndSettle();
    expect(find.text('Let calls ring on your lock screen'), findsNothing);
  });

  testWidgets('the devices card shows while blocked and goes once allowed',
      (tester) async {
    tester.view.physicalSize = const Size(390, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(app(
      ListView(
        padding: const EdgeInsets.all(16),
        children: const [CallRingCard()],
      ),
      access(),
      key,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Let calls ring on your lock screen'), findsOneWidget);
    await shot(tester, key, 'devices_card_w390');
    await tester.tap(find.text('Turn on'));
    expect(opened, 1);

    // Back from Settings with it turned on.
    allowed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Let calls ring on your lock screen'), findsNothing);
  });

  test('the settings page is opened natively, and only on Android 14+ first',
      () {
    final kt = File(
      'android/app/src/main/kotlin/org/auraplatform/app/MainActivity.kt',
    ).readAsStringSync();
    expect(kt, contains('"openFullScreenIntentSettings" ->'));
    expect(kt, contains('Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT'));
    expect(kt, contains('Settings.ACTION_APPLICATION_DETAILS_SETTINGS'));
  });
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    var any = false;
    for (final p in paths) {
      final f = File(p);
      if (!f.existsSync()) continue;
      final bytes = f.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      any = true;
    }
    if (any) await loader.load();
  }

  await load('AuraSerif', [
    'assets/fonts/SourceSerif4-500.ttf',
    'assets/fonts/SourceSerif4-600.ttf',
  ]);
  await load('AuraSans', [
    'assets/fonts/PublicSans-400.ttf',
    'assets/fonts/PublicSans-500.ttf',
    'assets/fonts/PublicSans-600.ttf',
    'assets/fonts/PublicSans-700.ttf',
  ]);
  await load('MaterialIcons', [
    'C:/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
  ]);
}
