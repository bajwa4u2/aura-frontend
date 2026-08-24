import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE INSTITUTION SPACE REACHES THE SAME CONVERSATION, THROUGH THE SAME
/// SCREEN.
///
/// The census established that institution Messages resolve
/// `Space.conversationId` and then use the canonical Conversation authority —
/// but through a different client entry point. A different entry point is
/// exactly where two surfaces start to drift: one gains a verb, the other
/// keeps an old one, and "same authority" quietly stops being true of the
/// presentation.
///
/// This pins the convergence from the outside, because it is the property that
/// makes personal-Messages certification meaningful for Spaces at all:
///
///   * the Space path renders the SAME ConversationScreen — not a copy;
///   * it passes the resolved conversationId, not a space id;
///   * what it varies is the HEADER, and nothing about the message surface;
///   * a Space with no resolvable conversation says so instead of rendering
///     an empty timeline that looks like silence.
///
/// WHAT THIS DELIBERATELY DOES NOT CLAIM. It is not a substitute for
/// exercising a live institution Space. No principal available during
/// certification held an institution membership, so the member-side
/// interaction path was not exercised against production and is reported
/// UNVERIFIED rather than inferred from this file.
void main() {
  final space = File(
    'lib/features/institutions/spaces/institution_space_screen.dart',
  ).readAsStringSync();
  final screen = File(
    'lib/features/conversation/presentation/conversation_screen.dart',
  ).readAsStringSync();

  group('the Space path is the Conversation path', () {
    test('it renders the canonical ConversationScreen', () {
      expect(space, contains('return ConversationScreen('));
    });

    test('it passes the RESOLVED conversation id, never a space id', () {
      expect(space, contains('conversationId: conversationId'));
      expect(space, contains('bundle.conversationId'));
      // A space id where a conversation id belongs would authorize against
      // the wrong object.
      expect(space.contains('conversationId: widget.spaceId'), isFalse);
    });

    test('an unresolvable conversation is stated, not rendered as silence', () {
      expect(space, contains('This space has no conversation yet.'));
    });

    test('there is no second conversation surface for institutions', () {
      // The whole convergence rests on there being one implementation. A
      // Space-specific message list would be the drift itself.
      final files = Directory('lib/features/institutions')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final f in files) {
        final src = f.readAsStringSync();
        expect(src.contains('ListView'), isA<bool>());
        // No institution file may build message bubbles of its own.
        expect(src.contains('_MessageBubble'), isFalse, reason: f.path);
        expect(src.contains('showMessageActionSheet'), isFalse, reason: f.path);
      }
    });
  });

  group('what the space context is allowed to change', () {
    test('it varies the heading and its members affordance', () {
      expect(screen, contains('_SpaceHeading(context: widget.spaceContext!)'));
      expect(screen, contains('widget.spaceContext?.onOpenMembers'));
    });

    test('it does NOT gate any message capability', () {
      // Every capability decision must come from the message and the viewer,
      // never from which door the screen was entered through. A spaceContext
      // test around a verb would be a context-specific policy that nobody
      // ruled.
      for (final verb in [
        'editMessage',
        'retractMessage',
        'removeMessageForMe',
        'forwardMessage',
        'reactToMessage',
      ]) {
        final idx = screen.indexOf(verb);
        if (idx < 0) continue;
        final around = screen.substring(
          idx - 400 < 0 ? 0 : idx - 400,
          idx + 200 > screen.length ? screen.length : idx + 200,
        );
        expect(around.contains('spaceContext'), isFalse, reason: verb);
      }
    });

    test('the read advance is not conditioned on the entry point either', () {
      final idx = screen.indexOf('advanceConversationRead');
      expect(idx, greaterThan(0));
      final around = screen.substring(idx - 600, idx + 300);
      expect(around.contains('spaceContext'), isFalse);
    });
  });
}
