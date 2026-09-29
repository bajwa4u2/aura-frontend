import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/feed/domain/feed_item.dart';

/// Every public post says what it is: Ask, Raise issue or Share update
/// (founder, 2026-09-29, option B: https://claude.ai/artifact/JEuASkaxxbMCHC1dWXMev7).
void main() {
  FeedItem userPost(Map<String, dynamic> extra) => FeedItem.fromJson({
        'id': 'p1',
        'type': 'USER_POST',
        'authorType': 'USER',
        'author': {'id': 'u1', 'type': 'user', 'name': 'A resident', 'handleOrSlug': 'res'},
        'body': 'The bus route to the district hospital was cut last month.',
        'visibility': 'PUBLIC',
        'distribution': 'GLOBAL_ELIGIBLE',
        'status': 'PUBLISHED',
        'targetRoute': '/posts/p1',
        'interaction': <String, dynamic>{},
        ...extra,
      });

  test('a feed item carries the intent its post was published with', () {
    expect(userPost({'intent': 'ISSUE'}).intent, 'ISSUE');
    expect(userPost({}).intent, isNull);
  });

  group('the composer asks at Publish', () {
    final composer =
        File('lib/features/posts/presentation/compose_screen.dart').readAsStringSync();
    final publish = composer.substring(composer.indexOf('Future<void> _publish() async'));

    test('a top-level post with nothing chosen is asked before it is sent', () {
      final ask = publish.indexOf('_askIntent(');
      final send = publish.indexOf('_posting = true');
      expect(ask, greaterThan(-1));
      expect(ask, lessThan(send), reason: 'asked after the post was already on its way');
      expect(publish.substring(0, ask), contains('!_isReply && !_isEditingPost'));
    });

    test('Raise issue is offered only when the server will accept it now', () {
      expect(composer, contains("'/public-record/capabilities/me'"));
      expect(composer, contains('Needs your identity verified. Your draft is kept.'));
    });

    test('a draft remembers what it is', () {
      expect(composer, contains("_intentFromWire(_str(draft['intent']))"));
      expect(composer, contains("case 'issue':"));
      expect(composer, contains("case 'update':"));
    });
  });
}
