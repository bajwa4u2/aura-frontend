import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/discover/presentation/discover_search.dart';

/// Two Discover search defects seen on a Galaxy S24+ (21 Oct 2026): a box
/// drawn inside the search box with its hint cut off, and the keyboard rising
/// by itself on returning from an opened result.
void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            enabledBorder: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(),
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(children: [
              const DiscoverSearchField(),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('An article')),
                )),
                child: const Text('Open result'),
              ),
            ]),
          ),
        ),
      ),
    ));
  }

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('one box, no theme border or fill inside it '
        '(${size.width.toInt()}px)', (tester) async {
      await pump(tester, size);
      final decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration!;
      expect(decoration.filled, isFalse);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.hintMaxLines, 1);
    });
  }

  testWidgets('the hint fits a phone', (tester) async {
    await pump(tester, const Size(390, 844));
    expect(find.text('Search people, spaces and more'), findsOneWidget);
  });

  testWidgets('the full hint on a wide screen', (tester) async {
    await pump(tester, const Size(1280, 800));
    expect(find.text('Search people, spaces, institutions, articles'),
        findsOneWidget);
  });

  testWidgets('coming back from a result does not refocus the field',
      (tester) async {
    await pump(tester, const Size(390, 844));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Open result'));
    await tester.pumpAndSettle();
    expect(find.text('An article'), findsOneWidget);

    Navigator.of(tester.element(find.text('An article'))).pop();
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isFalse);
  }, variant: TargetPlatformVariant.all());
}
