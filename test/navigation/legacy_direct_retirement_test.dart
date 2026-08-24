import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// LEGACY DIRECT IS RETIRED ON BOTH SIDES.
///
/// DirectThread stopped being a communication authority when its content was
/// reconciled into Conversation (2026-08-23) and the server's own `mapThread`
/// began answering `/messages/c/:conversationId` for a PERSON and an
/// INSTITUTION alike. The member address was cut over the same day.
///
/// The institution address was not, and neither were the two Direct inboxes.
/// So a durable institution link — a persisted notification deeplink, an older
/// released client — still reopened the legacy runtime, and two inboxes still
/// listed one body of correspondence while only one of them was being kept
/// true. Founder ruling 2026-08-24: eliminate the debt.
///
/// These are structural rather than behavioural on purpose. A future edit that
/// reintroduced any of these surfaces would look perfectly ordinary in review —
/// it is a builder, like every other route — and nothing else in the product
/// would notice until someone followed an old link.
void main() {
  final router = File('lib/router.dart').readAsStringSync();

  String routeBody(String path) {
    final start = router.indexOf("path: '$path'");
    expect(start, greaterThan(-1), reason: 'route $path is no longer declared');
    final next = router.indexOf('path: ', start + 10);
    return router.substring(start, next < 0 ? router.length : next);
  }

  test('the institution direct address resolves into canonical Conversation',
      () {
    final route = routeBody('/institution/:institutionId/direct/:threadId');
    expect(route, contains('DirectThreadCutoverScope'));
  });

  test('the legacy Direct surfaces are gone from the tree, not just unrouted',
      () {
    // Unreferenced-but-present is how a retired surface comes back: the next
    // person to need "an inbox" finds one already written.
    expect(
      File('lib/features/direct_threads/presentation/direct_thread_screen.dart')
          .existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/direct_threads/presentation/inbox_screen.dart')
          .existsSync(),
      isFalse,
    );
    expect(router.contains('DirectThreadScreen'), isFalse);
    expect(router.contains('InboxScreen'), isFalse);
  });

  test('both legacy Direct inbox addresses answer with the canonical inbox',
      () {
    // The addresses survive — a durable link is not deleted — but they resolve
    // rather than render.
    for (final path in [
      r'$kMessagesRoute/direct',
      r'$kMessagesRoute/direct/archived',
      '/institution/:institutionId/messages/direct',
      '/institution/:institutionId/messages/direct/archived',
    ]) {
      final route = routeBody(path);
      expect(route, contains('redirect:'), reason: '$path still renders');
      expect(route, contains('kMessagesRoute'), reason: '$path goes elsewhere');
    }
  });

  test('no in-product surface still links to a legacy Direct inbox', () {
    // The institution messaging screen offered a second "Direct messages"
    // inbox alongside Spaces; that was the only way in that was not a durable
    // external link.
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('router.dart')) continue;
      final s = f.readAsStringSync();
      if (s.contains('/messages/direct')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}
