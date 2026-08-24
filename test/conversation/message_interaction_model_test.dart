import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/conversation/presentation/message_interactions.dart';

/// INSIDE THE CONVERSATION — the interaction model, pinned from the outside.
///
/// Founder ruling 2026-08-24, §10–§12 and §19. The authorities are
/// established; the client can still undermine them by offering a verb to the
/// wrong person, by rendering a retracted message as though its content
/// survived, or by letting a reaction tap and a sheet tap take different paths.
void main() {
  String codeOnly(String src) => src
      .split(String.fromCharCode(10))
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('///') && !t.startsWith('*');
      })
      .join(String.fromCharCode(10));

  final interactionsRaw =
      File('lib/features/conversation/presentation/message_interactions.dart')
          .readAsStringSync();
  final interactions = codeOnly(interactionsRaw);
  final screen = codeOnly(
    File('lib/features/conversation/presentation/conversation_screen.dart')
        .readAsStringSync(),
  );

  group('the reaction vocabulary is the one that persists', () {
    test('it matches the backend ReactionType enum exactly', () {
      final schema = File('../aura-backend/prisma/schema.prisma');
      if (!schema.existsSync()) return; // backend not beside this repo
      final src = schema.readAsStringSync();
      final block = RegExp(r'enum ReactionType \{([^}]*)\}').firstMatch(src);
      expect(block, isNotNull);
      final serverTypes = block!
          .group(1)!
          .split(String.fromCharCode(10))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('/'))
          .toSet();

      final clientTypes = kMessageReactions.map((r) => r.type).toSet();
      // Offering a reaction the server cannot store is a control that fails.
      expect(clientTypes, equals(serverTypes));
    });

    test('an unknown type still renders as something', () {
      // The server vocabulary may grow before this list does; a reaction that
      // vanished would be worse than one drawn plainly.
      expect(reactionGlyph('SOMETHING_NEW'), isNotEmpty);
    });
  });

  group('eligibility is asked, not assumed', () {
    test('edit and retract are offered only to the author', () {
      // Offering them to anyone else produces a control that fails — the same
      // defect class as the Follow finding.
      expect(interactions, contains('if (mine)'));
      expect(interactions, contains('if (mine && !retracted)'));
    });

    test('a retracted message offers almost nothing', () {
      // There is no content left to reply to, forward, copy or react to.
      expect(interactions, contains('if (!retracted)'));
    });
  });

  group('retract and remove-for-me can never be confused', () {
    test('the wording separates shared from personal', () {
      expect(interactionsRaw, contains('withdrawn for everyone'));
      expect(interactionsRaw, contains('hides the message for you only'));
      expect(interactionsRaw, contains('Everyone else keeps it'));
    });

    test('both are confirmed before anything happens', () {
      expect(interactionsRaw, contains('Retract for everyone'));
      expect(interactionsRaw, contains('Remove for me'));
      expect(interactions, contains('if (!confirmed) return'));
    });
  });

  group('the surface renders lifecycle truthfully', () {
    test('a retracted message shows a tombstone, not its content', () {
      expect(screen, contains('if (message.deleted)'));
      expect(screen, contains('was withdrawn'));
      // The content branch is the ELSE — a retracted body is never rendered,
      // not even greyed out. Asserted on the raw source so comment stripping
      // cannot shift the window.
      final raw = File(
        'lib/features/conversation/presentation/conversation_screen.dart',
      ).readAsStringSync();
      final idx = raw.indexOf('if (message.deleted)');
      expect(idx, greaterThan(0));
      final branch = raw.substring(idx);
      final elseAt = branch.indexOf('else ...[');
      final attachmentAt = branch.indexOf('_ConversationAttachment');
      expect(elseAt, greaterThan(0));
      // Content rendering begins only AFTER the else.
      expect(attachmentAt, greaterThan(elseAt));
    });

    test('an edited message says so, and only when true', () {
      expect(screen, contains('message.wasEdited && !message.deleted'));
    });

    test('a forwarded message names who said it, never where', () {
      expect(screen, contains('forwardedFromSenderUserId'));
      expect(screen.contains('sourceConversationId'), isFalse);
    });
  });

  group('one path per act', () {
    test('the legacy four-action sheet is retired', () {
      expect(screen.contains('void _showMessageActions'), isFalse);
    });

    test('touch and pointer open the same sheet', () {
      expect(screen, contains('onLongPress: () => showMessageActionSheet'));
      expect(screen, contains('onSecondaryTap: () => showMessageActionSheet'));
    });

    test('every mutation re-reads the canonical projection', () {
      // Never a locally patched list: only the projection knows what this
      // viewer may see after a retract, an edit or a removal.
      expect(screen, contains('_reloadMessages'));
      expect(screen, contains('conversationMessagesProvider'));
    });

    test('the screen does not reimplement reaction toggling', () {
      // Toggle semantics belong to the engagement authority.
      expect(screen.contains('unreactMessage'), isFalse);
      expect(interactions, contains('unreactMessage'));
    });
  });

  group('realtime carries triggers, not content', () {
    test('the changed signal is subscribed and re-reads', () {
      final live = codeOnly(
        File('lib/features/correspondence/data/correspondence_live_service.dart')
            .readAsStringSync(),
      );
      expect(live, contains('conversation:message.changed'));
      expect(screen, contains('conversation:message.changed'));
    });

    test('the payload is never rendered directly', () {
      // The socket says what moved; the projection says what it now is.
      final idx = screen.indexOf('conversation:message.changed');
      final region = screen.substring(idx, idx + 700);
      expect(region, contains('invalidate'));
    });
  });

  group('forward offers only reachable destinations', () {
    test('it excludes the current conversation', () {
      expect(screen, contains('c.id != widget.conversationId'));
    });

    test('refused attachments are reported, not swallowed', () {
      expect(interactions, contains('hadRefusals'));
    });
  });
}
