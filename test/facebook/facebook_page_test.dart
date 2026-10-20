// Facebook Page sharing (2026-10-20): a member chooses one Page they manage.
// The chooser must make every postable Page choosable, and explain a Page the
// member cannot post to rather than hiding it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/me/presentation/widgets/facebook_page_connection.dart';

void main() {
  test('a Page option is read from the server list, which carries no token', () {
    final p = FacebookPageOption.fromJson({
      'id': '1214815621714960',
      'name': 'Aura Platform',
      'canPost': true,
      'pictureUrl': '',
    });
    expect(p.id, '1214815621714960');
    expect(p.canPost, isTrue);
    expect(p.pictureUrl, isNull);
  });

  testWidgets('the chooser returns the Page picked, and refuses one that cannot post', (
    tester,
  ) async {
    FacebookPageOption? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showFacebookPagePicker(context, const [
                  FacebookPageOption(id: 'A', name: 'Aura Platform', canPost: true),
                  FacebookPageOption(id: 'B', name: 'Read Only Page', canPost: false),
                ]);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Share to which Facebook Page?'), findsOneWidget);
    expect(find.text('You cannot post to this Page'), findsOneWidget);

    await tester.tap(find.text('Read Only Page'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Share to which Facebook Page?'), findsOneWidget);

    await tester.tap(find.text('Aura Platform'));
    await tester.pumpAndSettle();
    expect(picked?.id, 'A');
  });

  testWidgets('with no Pages, the chooser says what to do', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFacebookPagePicker(context, const []),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Facebook shows no Pages you manage'), findsOneWidget);
  });
}
