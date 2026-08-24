import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/conversation/data/conversations_repository.dart';
import 'package:aura/features/conversation/presentation/conversation_screen.dart';

/// WHO SAID THIS.
///
/// Observed in a live institution Space, 2026-08-24: a three-party
/// correspondence — the institution, the founder and one member — rendered an
/// incoming message as a bare bubble with no author anywhere on it. Every
/// message was there and every one of them was anonymous.
///
/// The name was never missing from the data. The timeline simply never asked
/// for it, and the surface this happens on is the SHARED one: personal group
/// correspondence and every institution Space render the same bubble, so the
/// defect was global rather than institutional.
///
/// The rules being pinned here are the ones that keep the fix from becoming
/// noise: a direct correspondence already names the other side in its header,
/// your own messages are attributed by their side of the timeline, and a run
/// of messages from one person is attributed by its first.
void main() {
  Conversation conv({required bool isDirect}) => Conversation.fromJson({
        'id': 'c1',
        'isDirect': isDirect,
        'parties': [
          {'kind': 'PERSON', 'userId': 'me', 'displayName': 'Me'},
          {'kind': 'PERSON', 'userId': 'them', 'displayName': 'Mrs Bajwa'},
          {
            'kind': 'INSTITUTION',
            'institutionId': 'i1',
            'displayName': 'Aura Platform'
          },
        ],
      });

  ConversationMessage msg(
    String id,
    String sender, {
    String? systemKind,
  }) =>
      ConversationMessage.fromJson({
        'id': id,
        'conversationId': 'c1',
        'senderUserId': sender,
        'body': 'x',
        'systemKind': systemKind,
        'createdAt': '2026-08-24T23:00:00.000Z',
      });

  bool ask(
    ConversationMessage m, {
    ConversationMessage? previous,
    bool isDirect = false,
  }) =>
      shouldNameSender(
        conversation: conv(isDirect: isDirect),
        message: m,
        previous: previous,
        myUserId: 'me',
      );

  test('a group message from someone else is named', () {
    // The defect, stated directly.
    expect(ask(msg('m1', 'them')), isTrue);
  });

  test('a direct correspondence does not repeat the header on every bubble',
      () {
    expect(ask(msg('m1', 'them'), isDirect: true), isFalse);
  });

  test('your own message is not labelled with your own name', () {
    expect(ask(msg('m1', 'me')), isFalse);
  });

  test('a run from one person is named once, by its first message', () {
    final first = msg('m1', 'them');
    final second = msg('m2', 'them');
    expect(ask(first), isTrue);
    expect(ask(second, previous: first), isFalse);
  });

  test('the name returns as soon as the speaker changes', () {
    expect(ask(msg('m2', 'them'), previous: msg('m1', 'me')), isTrue);
  });

  test('a system event breaks the run', () {
    // Once "X joined the conversation" has come between them, the reader's eye
    // has left the sender and the next message needs its author again.
    final joined = msg('m2', 'them', systemKind: 'JOINED');
    expect(ask(msg('m3', 'them'), previous: joined), isTrue);
  });

  test('a system message is never given a sender label', () {
    // It already names its actor in its own sentence.
    expect(ask(msg('m1', 'them', systemKind: 'LEFT')), isFalse);
  });
}
