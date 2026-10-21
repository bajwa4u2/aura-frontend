import 'dart:io';

import 'package:aura/core/tagging/governed_tag_field.dart';
import 'package:aura/core/ui/aura_platform_components.dart' show AuraAvatar;
import 'package:aura/features/search/providers.dart';
import 'package:aura/features/search/search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// @ / # suggestions follow each platform (founder, 21 Oct 2026): a popover
/// at the line being typed on Windows, macOS, Linux and desktop-width web; a
/// chip strip on the keyboard on phones and phone-width web. Before, the
/// list sat at the bottom of a desktop window and the top edge of a phone.
/// A picked person keeps their photo once attached.
class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository() : super(Dio());

  @override
  Future<SearchResult> search(String q, {int limit = 12}) async {
    return const SearchResult(
      people: [
        {
          'id': 'user-2',
          'handle': 'neighbor',
          'displayName': 'Neighbor Person',
          'avatarUrl': 'https://example.test/neighbor.jpg',
        },
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
  double keyboard = 0,
  double topSpacer = 0,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GovernedTagAutocomplete(
                    controller: controller,
                    focusNode: focusNode,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 3,
                      maxLines: 3,
                    ),
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

Future<void> _type(WidgetTester tester, String text) async {
  await tester.showKeyboard(find.byType(TextField));
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

/// The window's size and, like a real phone, the keyboard as the window's
/// own inset (not a MediaQuery a Scaffold may already have consumed).
void _size(WidgetTester tester, Size size, {double keyboard = 0}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

const _popover = ValueKey('tag-suggestion-popover');
const _strip = ValueKey('tag-suggestion-strip');

void main() {
  group('which presentation each platform gets', () {
    test('desktop is a popover; phones a strip; web by width', () {
      for (final p in [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]) {
        expect(
          tagSuggestionPresentationFor(platform: p, isWeb: false, width: 400),
          TagSuggestionPresentation.popover,
        );
      }
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(
          tagSuggestionPresentationFor(platform: p, isWeb: false, width: 1200),
          TagSuggestionPresentation.strip,
        );
      }
      expect(
        tagSuggestionPresentationFor(platform: TargetPlatform.windows, isWeb: true, width: 1280),
        TagSuggestionPresentation.popover,
      );
      expect(
        tagSuggestionPresentationFor(platform: TargetPlatform.android, isWeb: true, width: 390),
        TagSuggestionPresentation.strip,
      );
    });
  });

  group('desktop: a popover at the line being typed', () {
    testWidgets('opens just below the line, left edge at the @', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _size(tester, const Size(1280, 800));
      final controller = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(_harness(controller: controller, focusNode: focus));
      await _type(tester, 'Hello @ne');

      expect(find.byKey(_strip), findsNothing);
      final panel = tester.getRect(find.byKey(_popover));
      final field = tester.getRect(find.byType(TextField));
      // Below the first line, inside the field — not at the window bottom.
      expect(panel.top, lessThan(field.top + 60));
      expect(panel.top, greaterThan(field.top));
      // Not at the field's left edge: hanging from the "@" after "Hello ".
      expect(panel.left, greaterThan(field.left + 20));
      expect(panel.width, 320);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('flips above the line only when the window has no room below',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _size(tester, const Size(1280, 800));
      final controller = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(
        _harness(controller: controller, focusNode: focus, topSpacer: 690),
      );
      await _type(tester, 'Hello @ne');

      final panel = tester.getRect(find.byKey(_popover));
      final field = tester.getRect(find.byType(TextField));
      expect(panel.bottom, lessThanOrEqualTo(field.top + 30));
      expect(panel.top, greaterThanOrEqualTo(0));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('↓ then Enter picks the second; Esc closes; Tab picks',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _size(tester, const Size(1280, 800));
      final controller = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(_harness(controller: controller, focusNode: focus));

      await _type(tester, 'Hi @n');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(_popover), findsNothing);

      await _type(tester, 'Hi @ne');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.text, startsWith('Hi @Next Door'));
      expect(find.byKey(_popover), findsNothing);

      await _type(tester, 'Yo @ne');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(controller.text, startsWith('Yo @Neighbor Person'));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('phones: a strip on the keyboard', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('sits directly on the keyboard (${platform.name})', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        _size(tester, const Size(390, 844), keyboard: 300);
        final controller = TextEditingController();
        final focus = FocusNode();
        await tester.pumpWidget(
          _harness(controller: controller, focusNode: focus, keyboard: 300),
        );
        await _type(tester, 'Hello @ne');

        expect(find.byKey(_popover), findsNothing);
        final strip = tester.getRect(find.byKey(_strip));
        expect(strip.bottom, moreOrLessEquals(844 - 300, epsilon: 1));
        expect(strip.left, 0);
        expect(strip.width, 390);
        // Never over the line being typed.
        expect(strip.top, greaterThan(tester.getRect(find.byType(TextField)).top + 20));

        await tester.tap(find.text('Next Door'));
        await tester.pump();
        expect(controller.text, startsWith('Hello @Next Door'));
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('when the keyboard edge would cover the line, it sits above it',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _size(tester, const Size(390, 844), keyboard: 300);
      final controller = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(_harness(
        controller: controller,
        focusNode: focus,
        keyboard: 300,
        topSpacer: 844 - 300 - 70,
      ));
      await _type(tester, 'Hello @ne');

      final strip = tester.getRect(find.byKey(_strip));
      final field = tester.getRect(find.byType(TextField));
      expect(strip.bottom, lessThanOrEqualTo(field.top + 30));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('inside the shell, as on the S24+ (keyboard 1005 px)', () {
    // 21 Oct 2026: in Messages the strip was built at the screen bottom,
    // under the keyboard. A Scaffold that resizes for the keyboard had
    // consumed viewInsets below it, so the field read 0. This reproduces
    // that nesting with the keyboard as the window's own inset.
    Widget shell({
      required TextEditingController controller,
      required FocusNode focusNode,
      required bool composerAtBottom,
    }) {
      final field = GovernedTagAutocomplete(
        controller: controller,
        focusNode: focusNode,
        child: TextField(controller: controller, focusNode: focusNode),
      );
      return ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            // The shell.
            bottomNavigationBar: const SizedBox(height: 64),
            body: Scaffold(
              // The page, resizing for the keyboard.
              resizeToAvoidBottomInset: true,
              body: Column(
                children: [
                  if (!composerAtBottom)
                    Padding(padding: const EdgeInsets.all(16), child: field),
                  const Expanded(child: SizedBox()),
                  if (composerAtBottom)
                    Padding(padding: const EdgeInsets.all(8), child: field),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the strip sits exactly on the keyboard', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _size(tester, const Size(1080, 2340), keyboard: 1005);
      final controller = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(
        shell(controller: controller, focusNode: focus, composerAtBottom: false),
      );
      await _type(tester, 'Testing mentions @ne');

      final strip = tester.getRect(find.byKey(_strip));
      expect(strip.bottom, moreOrLessEquals(2340 - 1005, epsilon: 0.5));
      expect(strip.width, 1080);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a composer on the keyboard keeps its line: the strip sits '
        'just above it, fully visible', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _size(tester, const Size(1080, 2340), keyboard: 1005);
      final controller = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(
        shell(controller: controller, focusNode: focus, composerAtBottom: true),
      );
      await _type(tester, 'Testing mentions @ne');

      final strip = tester.getRect(find.byKey(_strip));
      final field = tester.getRect(find.byType(TextField));
      expect(field.bottom, lessThanOrEqualTo(2340 - 1005 + 0.5));
      expect(strip.bottom, lessThanOrEqualTo(field.top + 20));
      expect(strip.top, greaterThan(0));
      expect(strip.bottom, lessThanOrEqualTo(2340 - 1005));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('desktop: the popover hangs from the line inside the shell too',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _size(tester, const Size(1280, 800));
    final controller = TextEditingController();
    final focus = FocusNode();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const SizedBox(width: 240), // the rail
              Expanded(
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.fromLTRB(40, 300, 40, 0),
                    child: GovernedTagAutocomplete(
                      controller: controller,
                      focusNode: focus,
                      child: TextField(controller: controller, focusNode: focus),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await _type(tester, 'Hello @ne');
    final panel = tester.getRect(find.byKey(_popover));
    final field = tester.getRect(find.byType(TextField));
    expect(panel.left, greaterThan(field.left + 20));
    expect(panel.top, greaterThan(field.top));
    expect(panel.top, lessThan(field.bottom + 8));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('nothing opens on the sigil alone', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _size(tester, const Size(1280, 800));
    final controller = TextEditingController();
    final focus = FocusNode();
    await tester.pumpWidget(_harness(controller: controller, focusNode: focus));
    await _type(tester, 'Hello @');
    expect(find.byKey(_popover), findsNothing);
    await _type(tester, 'Hello @n');
    expect(find.byKey(_popover), findsOneWidget);
    await _type(tester, 'Hello @n ');
    expect(find.byKey(_popover), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('a picked person is attached with the same photo '
        '(${platform.name})', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _size(tester, platform == TargetPlatform.android
          ? const Size(390, 844)
          : const Size(1280, 800));
      final controller = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(_harness(controller: controller, focusNode: focus));
      await _type(tester, 'Thanks @nei');
      await tester.tap(find.text('Neighbor Person').last);
      await tester.pump();

      final row = find.byKey(const ValueKey('attached-tag-row'));
      expect(row, findsOneWidget);
      final avatar = tester.widget<AuraAvatar>(
        find.descendant(of: row, matching: find.byType(AuraAvatar)),
      );
      expect(avatar.imageUrl, 'https://example.test/neighbor.jpg');
      expect(avatar.name, 'Neighbor Person');

      // × takes the person out of the text, and the chip goes with it.
      await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.close_rounded)));
      await tester.pump();
      expect(controller.text.contains('@Neighbor Person'), isFalse);
      expect(find.byKey(const ValueKey('attached-tag-row')), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('a person without a photo is attached with their initial',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _size(tester, const Size(390, 844));
    final controller = TextEditingController();
    final focus = FocusNode();
    await tester.pumpWidget(_harness(controller: controller, focusNode: focus));
    await _type(tester, 'Thanks @nex');
    await tester.tap(find.text('Next Door').last);
    await tester.pump();
    final row = find.byKey(const ValueKey('attached-tag-row'));
    expect(find.descendant(of: row, matching: find.text('N')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  group('every composer uses the one governed list', () {
    final composers = {
      'lib/features/posts/presentation/compose_screen.dart': 'post and reply',
      'lib/features/institutions/posts/institution_post_composer_screen.dart':
          'institution post',
      'lib/features/institutions/announcements/institution_announcement_composer.dart':
          'institution announcement',
      'lib/features/conversation/presentation/conversation_screen.dart':
          'messages',
    };
    composers.forEach((path, name) {
      test('$name passes its attached tags', () {
        final src = File(path).readAsStringSync();
        expect(src, contains('GovernedTagAutocomplete('));
        expect(src, contains('attached: _selectedTagReferences,'));
      });
    });

    test('messages no longer has its own chip row of people', () {
      final src = File(
        'lib/features/conversation/presentation/conversation_screen.dart',
      ).readAsStringSync();
      expect(src.contains('_mentionMatches'), isFalse);
      expect(src.contains('_insertMention'), isFalse);
    });
  });
}
