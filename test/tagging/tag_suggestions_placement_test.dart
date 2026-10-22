import 'package:aura/core/tagging/governed_tag_field.dart';
import 'package:aura/features/search/providers.dart';
import 'package:aura/features/search/search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The @ / # suggestions stay on screen: at the caret, below it when there is
/// room before the keyboard or window bottom, above it otherwise. A tall post
/// composer used to hang them under the field's bottom edge, under the
/// keyboard (found on a Galaxy S24+, 21 Oct 2026).
class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository() : super(Dio());

  @override
  Future<SearchResult> search(String q, {int limit = 12}) async {
    return const SearchResult(
      people: [
        {'id': 'user-2', 'handle': 'neighbor', 'displayName': 'Neighbor Person'},
        {'id': 'user-3', 'handle': 'next', 'displayName': 'Next Door'},
      ],
      institutions: [],
      spaces: [],
      articles: [],
    );
  }
}

Widget _harness({
  required TextEditingController controller,
  required FocusNode focusNode,
  required double keyboard,
  required double topSpacer,
}) {
  return ProviderScope(
    overrides: [
      searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: ListView(
              children: [
                SizedBox(height: topSpacer),
                GovernedTagAutocomplete(
                  controller: controller,
                  focusNode: focusNode,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 10,
                    maxLines: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Rect _panelRect(WidgetTester tester) =>
    tester.getRect(find.ancestor(
      of: find.text('Neighbor Person'),
      matching: find.byType(Material),
    ).first);

void main() {
  // The caret placement is the desktop popover's (Windows, macOS, Linux,
  // desktop-width web). Phones show a strip on the keyboard instead; see
  // tag_suggestions_per_platform_test.dart.
  final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('caret low on screen with a keyboard: list opens above it, '
        'fully visible (${size.width.toInt()}px)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final keyboard = size.width < 600 ? 300.0 : 0.0;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(_harness(
        controller: controller,
        focusNode: focusNode,
        keyboard: keyboard,
        topSpacer: size.height - keyboard - 260,
      ));
      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(
          find.byType(TextField), 'line\nline\nline\nline\nline\nHello @nei');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Neighbor Person'), findsOneWidget);
      final panel = _panelRect(tester);
      expect(panel.top, greaterThanOrEqualTo(0));
      expect(panel.bottom, lessThanOrEqualTo(size.height - keyboard));
      expect(panel.left, greaterThanOrEqualTo(0));
      expect(panel.right, lessThanOrEqualTo(size.width));
    }, variant: desktop);
  }

  testWidgets('room below the caret: list opens below it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(_harness(
      controller: controller,
      focusNode: focusNode,
      keyboard: 0,
      topSpacer: 0,
    ));
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Hello @nei');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    final field = tester.getRect(find.byType(TextField));
    final panel = _panelRect(tester);
    // Below the first line, i.e. inside the field's height, not under it.
    expect(panel.top, lessThan(field.top + 80));
    expect(panel.bottom, lessThanOrEqualTo(844));
  }, variant: desktop);
}
