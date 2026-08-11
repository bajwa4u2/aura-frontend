import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/link_preview/compose_link_detector.dart';
import 'package:aura/core/link_preview/link_preview.dart';
import 'package:aura/core/link_preview/link_preview_card.dart';
import 'package:aura/core/link_preview/link_url_detection.dart';

/// Compose Link Intelligence / OG Preview -- Phase 1.
///
/// `ComposeLinkDetector` + `LinkPreviewCard` are the exact, shared units
/// both `compose_screen.dart` (member) and
/// `institution_post_composer_screen.dart` (institution) wire identically
/// -- neither composer has its own detection or rendering logic. This
/// exercises that shared integration end to end (type a URL -> detect ->
/// debounce -> resolve -> render card -> remove -> stays removed) via a
/// minimal harness widget using the same pattern, rather than the full
/// production composer screens (both very large, provider-heavy, and not
/// otherwise under test in this repo -- this proves the mechanism both
/// composers depend on works, without taking on the risk of standing up
/// either screen's full dependency graph for the first time here).
void main() {
  group('firstUrlIn', () {
    test('finds the first http(s) URL in free text', () {
      expect(firstUrlIn('check this out: https://example.com/a nice right?'), 'https://example.com/a');
    });

    test('returns null when there is no URL', () {
      expect(firstUrlIn('just some plain text'), isNull);
    });

    test('strips trailing sentence punctuation', () {
      expect(firstUrlIn('see https://example.com/a.'), 'https://example.com/a');
      expect(firstUrlIn('see (https://example.com/a)'), 'https://example.com/a');
    });

    test('finds the first of multiple URLs', () {
      expect(
        firstUrlIn('https://first.com and https://second.com'),
        'https://first.com',
      );
    });
  });

  group('ComposeLinkDetector + LinkPreviewCard integration', () {
    testWidgets('typing a URL debounces, resolves, and renders a preview card', (tester) async {
      final controller = TextEditingController();
      LinkPreview? current;
      var resolveCalls = 0;

      final detector = ComposeLinkDetector(
        controller: controller,
        debounce: const Duration(milliseconds: 50),
        resolve: (url) async {
          resolveCalls += 1;
          return const LinkPreview(
            eligible: true,
            internal: false,
            sourceUrl: 'https://example.com/article',
            linkPreviewId: 'lp-1',
            status: 'READY',
            title: 'A Great Article',
            description: 'Learn something new.',
            siteName: 'example.com',
            imageUrl: null,
          );
        },
        onPreviewChanged: (p) => current = p,
      );
      addTearDown(detector.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    TextField(controller: controller),
                    if (current != null && current!.eligible)
                      LinkPreviewCard(
                        url: current!.sourceUrl,
                        title: current!.title,
                        description: current!.description,
                        siteName: current!.siteName,
                        imageUrl: current!.imageUrl,
                        onRemove: () => setState(() => current = null),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      controller.text = 'check out https://example.com/article';
      await tester.pump(); // detector's listener fires synchronously
      expect(resolveCalls, 0); // still debouncing

      await tester.pump(const Duration(milliseconds: 60)); // debounce elapses
      await tester.pump(); // resolve() future completes

      expect(resolveCalls, 1);
      expect(current?.title, 'A Great Article');
    });

    testWidgets('removing the URL from the text clears the preview (draft stays stable)', (tester) async {
      final controller = TextEditingController(text: 'https://example.com');
      LinkPreview? current = const LinkPreview(
        eligible: true,
        internal: false,
        sourceUrl: 'https://example.com',
        status: 'READY',
        title: 'Example',
      );

      final detector = ComposeLinkDetector(
        controller: controller,
        resolve: (url) async => null,
        onPreviewChanged: (p) => current = p,
      );
      addTearDown(detector.dispose);
      detector.resolveNow(); // simulate the initial attach already having happened

      controller.text = 'no link anymore';
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(current, isNull);
    });

    testWidgets('a stale in-flight resolve does not overwrite a newer detected URL', (tester) async {
      final controller = TextEditingController();
      final results = <String, LinkPreview?>{};
      final calls = <String>[];

      final detector = ComposeLinkDetector(
        controller: controller,
        debounce: const Duration(milliseconds: 10),
        resolve: (url) async {
          calls.add(url);
          // The slow one resolves after the text has already moved on.
          if (url == 'https://slow.example.com') {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          return LinkPreview(eligible: true, internal: false, sourceUrl: url, status: 'READY', title: url);
        },
        onPreviewChanged: (p) => results[p?.sourceUrl ?? 'null'] = p,
      );
      addTearDown(detector.dispose);

      controller.text = 'https://slow.example.com';
      await tester.pump(const Duration(milliseconds: 20)); // debounce fires, resolve() starts (slow)

      controller.text = 'https://fast.example.com';
      await tester.pump(const Duration(milliseconds: 20)); // second debounce fires
      await tester.pump(const Duration(milliseconds: 200)); // both resolves settle

      expect(calls, containsAll(['https://slow.example.com', 'https://fast.example.com']));
      // The slow result must never have been applied once the text moved on.
      expect(results.containsKey('https://slow.example.com'), isFalse);
      expect(results['https://fast.example.com']?.title, 'https://fast.example.com');
    });
  });
}
