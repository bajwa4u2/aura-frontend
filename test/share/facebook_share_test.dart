// Share to Facebook: Facebook lets no app post to a personal profile, so Aura
// opens Facebook's own share page with the public link; the member sees the
// preview card and decides. These checks keep the link exact and keep the
// choice beside LinkedIn in the share sheet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/posts/presentation/widgets/post_card/post_card_utils.dart';
import 'package:aura/features/share/aura_share_sheet.dart';

void main() {
  test(
    'the Facebook link is Facebook\'s share page carrying the encoded Aura link',
    () {
      const post = 'https://auraplatform.org/posts/abc123?x=1&y=2';
      expect(
        facebookShareUrl(post),
        'https://www.facebook.com/sharer/sharer.php?u=https%3A%2F%2Fauraplatform.org%2Fposts%2Fabc123%3Fx%3D1%26y%3D2',
      );
    },
  );

  testWidgets('the share sheet offers Facebook right after LinkedIn', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAuraShareSheet(
                context,
                shareUrl: 'https://auraplatform.org/posts/abc123',
                headline: 'Share this work',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final labels = [
      'Copy link',
      'Share to LinkedIn',
      'Share to Facebook',
      'Share to Email',
    ];
    for (final l in labels) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    final ys = labels.map((l) => tester.getTopLeft(find.text(l)).dy).toList();
    for (var i = 1; i < ys.length; i++) {
      expect(
        ys[i],
        greaterThan(ys[i - 1]),
        reason: '${labels[i]} comes after ${labels[i - 1]}',
      );
    }
  });
}
