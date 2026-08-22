// TRANSLATE BELONGS TO THE ARTICLE, NOT TO THE DISCUSSION.
//
// Founder-observed: the Translate control rendered BELOW the discussion
// composer and "No replies yet.", which visually said it acted on the
// discussion. Placement was the whole meaning of the control.
//
// Intended hierarchy:
//   ARTICLE CONTENT -> ARTICLE ACTIONS (React / Translate / Save, Reshare)
//   -> DISCUSSION (composer, replies)
//
// A screenshot found this; an ordering assertion keeps it found.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/translation/communication_translate_action.dart';
import 'package:aura/core/translation/communication_translation.dart';

const _kScreen = 'lib/features/articles/presentation/article_screen.dart';

void main() {
  late String src;

  setUpAll(() {
    final whole = File(_kScreen).readAsStringSync();
    // Only the RENDERED composition. Searching the whole file measured where
    // classes are DECLARED, not where widgets appear — `_ArticleActions` is
    // declared below the screen, so a correct layout still "failed". A test
    // that can be satisfied by moving a class definition is not testing
    // layout at all.
    final actionsClass = whole.indexOf('class _ArticleActions');
    src = actionsClass == -1 ? whole : whole.substring(0, actionsClass);
  });

  late String actionsSrc;

  setUpAll(() {
    final whole = File(_kScreen).readAsStringSync();
    final start = whole.indexOf('class _ArticleActions');
    final end = whole.indexOf('/// DISCOVER', start);
    actionsSrc = whole.substring(start, end == -1 ? whole.length : end);
  });

  group('article action ordering', () {
    test('Translate is rendered BEFORE the discussion, never after it', () {
      // The action region is rendered as one widget, so its position IS
      // Translate's position.
      final translate = src.indexOf('_ArticleActions(');
      final discussion = src.indexOf('AuraPublicationDiscussion(');
      expect(translate, isNot(-1));
      expect(discussion, isNot(-1));
      expect(translate, lessThan(discussion),
          reason: 'Below the discussion, Translate reads as translating the '
              'replies rather than the article.');
    });

    test('Translate sits INSIDE the article action row, beside React and Save',
        () {
      // Not merely "somewhere above" — the row is what makes it read as an
      // article action rather than a stray control.
      expect(actionsSrc, contains('inlineAction: CommunicationTranslateAction('));
    });

    test('the translation renders attributed to the ARTICLE', () {
      expect(actionsSrc, contains('AuraTranslationResult('));
      expect(actionsSrc, contains('AuraPublicationMarkdown(data: text)'));
    });

    test('Reshare remains its own distinct publication action', () {
      // Reshare lives inside the action region, which itself renders before
      // the discussion — so it is a publication action, not a reply action.
      expect(actionsSrc, contains("label: const Text('Reshare on Aura')"));
      final translate = actionsSrc.indexOf('CommunicationTranslateAction(');
      final reshare = actionsSrc.indexOf("Text('Reshare on Aura')");
      expect(translate, lessThan(reshare),
          reason: 'React/Translate/Save first, then Reshare — the founder-'
              'stated hierarchy.');
    });

    test('external Share stays at the top, where the founder confirmed it', () {
      final share = src.indexOf('showAuraShareSheet(');
      final actions = src.indexOf('_ArticleActions(');
      expect(share, isNot(-1));
      expect(share, lessThan(actions),
          reason: 'The share affordance was confirmed good where it is and '
              'must not drift into the action row.');
    });
  });

  testWidgets('the inline control sizes to content, so it can sit in a row',
      (tester) async {
    // A max-width Column or Row inside a horizontal action row demands
    // unbounded width and overflows. This is the constraint that lets
    // Translate live beside React and Save at all.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              CommunicationTranslateAction(
                objectType: CommunicationObjectType.post,
                objectId: 'p1',
                sourceText: 'text',
                inline: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
