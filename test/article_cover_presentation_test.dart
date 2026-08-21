import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/publication/aura_article_cover.dart';

/// ARTICLE COVER PRESENTATION — founder-reported defect.
///
/// The first version framed the cover as AspectRatio(16/9) + BoxFit.cover, which
/// is a decision to DISCARD composition. A landscape artwork lost a substantial
/// part of its lower composition because the FRAME decided the shape rather than
/// the artwork. A cover is authored media; a renderer must not silently re-crop
/// it on the author's behalf.
///
/// These pin the contract, not the pixels: no cropping fit, a height bound that
/// scales with the viewport, and one widget shared by reader and composer.
void main() {
  group('the cover never crops authored composition', () {
    testWidgets('uses a non-cropping fit', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AuraArticleCover('https://example.test/c.png')),
      ));
      final img = tester.widget<Image>(find.byType(Image));
      // BoxFit.cover and fitWidth both discard part of the image when the frame
      // disagrees with the aspect ratio. contain never does.
      expect(img.fit, BoxFit.contain);
      expect(img.fit, isNot(BoxFit.cover));
    });

    testWidgets('the frame does not impose a fixed aspect ratio', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AuraArticleCover('https://example.test/c.png')),
      ));
      // An AspectRatio here would mean the frame, not the artwork, decides the
      // shape — which is exactly what cropped the founder's cover.
      expect(find.byType(AspectRatio), findsNothing);
    });

    testWidgets('an empty url renders nothing at all', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AuraArticleCover('   ')),
      ));
      expect(find.byType(Image), findsNothing);
    });
  });

  group('the height bound is responsive, and only ever scales down', () {
    test('taller viewports allow a taller cover', () {
      expect(AuraArticleCover.maxHeightFor(1200),
          greaterThan(AuraArticleCover.maxHeightFor(700)));
    });

    test('a short viewport still leaves room for the headline', () {
      // On a small screen the cover must not become the entire first screen.
      expect(AuraArticleCover.maxHeightFor(640), lessThan(640 * 0.75));
    });

    test('bounded at both ends so it is never absurd', () {
      expect(AuraArticleCover.maxHeightFor(200), greaterThanOrEqualTo(220));
      expect(AuraArticleCover.maxHeightFor(4000), lessThanOrEqualTo(620));
    });
  });

  group('reader and composer cannot disagree', () {
    testWidgets('the author-facing variant differs only in failure affordance',
        (tester) async {
      // Same widget, same fit, same bound — the ONLY difference is that an
      // author is told when a cover fails and offered a retry, because an author
      // can act on it and a reader cannot.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AuraArticleCover('https://example.test/c.png', showFailure: true),
        ),
      ));
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.fit, BoxFit.contain);
    });
  });
}
