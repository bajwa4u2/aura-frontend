import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/features/posts/presentation/widgets/post_card.dart';
import 'package:aura/core/ui/aura_space.dart';
import 'package:aura/core/ui/aura_surface.dart';
import 'package:aura/core/ui/aura_text.dart';
import 'package:aura/core/ui/surface/surface_composition.dart';
import 'package:aura/features/feed/domain/feed_item.dart';
import 'package:aura/features/feed/presentation/feed_filter_bar.dart';
import 'package:aura/features/feed/presentation/unified_feed_card.dart';
import 'package:aura/features/public/widgets/public_composer.dart';
import 'package:aura/features/public/widgets/space_card.dart';

/// Review harness for the member home's top: composer, spaces, filters and the
/// first posts, as a member lands. Writes PNGs only when SPACES_SHOTS=<dir>;
/// SPACES_TAG names the set (before/after). Not a pixel test.
void main() {
  final shots = Platform.environment['SPACES_SHOTS'];
  final tag = Platform.environment['SPACES_TAG'] ?? 'after';

  FeedItem post(int i, String name, String body) => FeedItem.fromJson({
        'id': 'p$i',
        'type': 'USER_POST',
        'authorType': 'USER',
        'author': {'id': 'u$i', 'type': 'USER', 'name': name, 'handleOrSlug': 'm$i'},
        'body': body,
        'visibility': 'PUBLIC',
        'status': 'PUBLISHED',
        'publishedAt': DateTime.utc(2026, 10, 26, 14 - i).toIso8601String(),
        'createdAt': DateTime.utc(2026, 10, 26, 14 - i).toIso8601String(),
        'targetRoute': '/posts/p$i',
        'interaction': <String, dynamic>{},
      });

  final posts = [
    post(1, 'Maya R.', 'Will the library keep weekend hours through the winter? Asking for the reading group that meets on Saturdays.'),
    post(2, 'Amir K.', 'Posting from the phone for the first time. Reading in Community this morning.'),
    post(3, 'Canton Library', 'Saturdays 10 to 5, all winter. We will post here if that changes.'),
  ];

  Future<void> pumpHome(WidgetTester tester, Size size, GlobalKey key,
      {TextDirection direction = TextDirection.ltr}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          backgroundColor: AuraSurface.page,
          body: AuraSurfaceScaffold(
            type: AuraSurfaceType.discourseFeed,
            center: ListView(
              padding: const EdgeInsets.fromLTRB(0, AuraSpace.s12, 0, AuraSpace.s32),
              children: [
                const PublicComposer(),
                const SizedBox(height: AuraSpace.s14),
                if (tag == 'before') ...[
                  const Text('Spaces', style: AuraText.subtitle),
                  const SizedBox(height: AuraSpace.s10),
                ],
                const PublicSpacesStrip(),
                const SizedBox(height: AuraSpace.s16),
                const FeedFilterBar(),
                const SizedBox(height: AuraSpace.s14),
                for (final p in posts) ...[
                  UnifiedFeedCard(item: p, showReplyPreview: false),
                  const SizedBox(height: AuraSpace.s12),
                ],
              ],
            ),
          ),
        ),
      ),
      GoRoute(path: '/spaces', builder: (_, __) => const Text('ALL SPACES')),
      GoRoute(path: '/spaces/:slug', builder: (_, s) => Text('SPACE ${s.pathParameters['slug']}')),
    ]);
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [
          isAuthedProvider.overrideWithValue(true),
          authMeDataProvider.overrideWith((ref) async => {
                'id': 'me',
                'displayName': 'M S Bajwa',
                'handle': 'bajwawrites',
              }),
          viewerIdentityProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
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
          builder: (context, child) =>
              Directionality(textDirection: direction, child: child!),
          routerConfig: router,
        ),
      ),
    ));
    for (var i = 0; i < 20; i++) {
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
    for (final size in const [Size(1440, 900), Size(390, 844)]) {
      final key = GlobalKey();
      await pumpHome(tester, size, key);
      final firstPost = tester.getTopLeft(find.byType(UnifiedFeedCard).first);
      // ignore: avoid_print
      print('SPACES_REVIEW $tag ${size.width.toInt()}x${size.height.toInt()} firstPostY=${firstPost.dy}');
      await save(tester, key, '${tag}_${size.width.toInt()}x${size.height.toInt()}');
      if (tag == 'after' && size.width == 1440) {
        for (var f = 1; f <= 3; f++) {
          for (var k = 0; k < 60; k++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          await save(tester, key, 'after_1440_drift_$f');
        }
        final rtlKey = GlobalKey();
        await pumpHome(tester, size, rtlKey, direction: TextDirection.rtl);
        await tester.pump(const Duration(seconds: 2));
        await save(tester, rtlKey, 'after_1440_rtl');
      }
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
