import 'dart:io';

import 'package:aura/core/net/data_changes.dart';
import 'package:aura/features/feed/data/unified_feed_providers.dart';
import 'package:aura/features/feed/domain/feed_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A REFRESH KEEPS THE READER'S PLACE (2026-10-25). Founder: "it should keep
/// its place even where ever refresh or edit action happened but its not
/// keeping almost most of the places".
FeedItem _post(String id, {String body = 'text'}) => FeedItem.fromJson({
      'id': id,
      'type': 'POST',
      'authorType': 'PERSON',
      'author': {
        'id': 'u1',
        'type': 'PERSON',
        'name': 'Someone',
        'handleOrSlug': 'someone',
        'profileRoute': '/u/someone',
      },
      'title': '',
      'body': body,
      'media': const <dynamic>[],
      'visibility': 'PUBLIC',
      'createdAt': '2026-10-25T20:00:00.000Z',
    });

List<String> _ids(FeedPagedNotifier n) =>
    n.state.value!.items.map((e) => e.id).toList();

void main() {
  group('a paged feed refreshes in place', () {
    test('pages already read stay, after the fresh first page', () async {
      var serve = <String?, FeedPage>{
        null: FeedPage(items: [_post('a'), _post('b')], nextCursor: 'c2'),
        'c2': FeedPage(items: [_post('c'), _post('d')], nextCursor: 'c3'),
      };
      final n = FeedPagedNotifier(({cursor}) async => serve[cursor]!);
      await Future<void>.delayed(Duration.zero);
      await n.loadMore();
      expect(_ids(n), ['a', 'b', 'c', 'd']);

      // A new post above, and b edited: the reader keeps c and d.
      serve = {
        null: FeedPage(
          items: [_post('new'), _post('a'), _post('b', body: 'edited')],
          nextCursor: 'x',
        ),
      };
      await n.refresh();
      expect(_ids(n), ['new', 'a', 'b', 'c', 'd']);
      expect(n.state.value!.items[2].body, 'edited');
      expect(n.state.value!.nextCursor, 'c3');
    });

    test('a post deleted within the first page does not survive', () async {
      var first = FeedPage(items: [_post('a'), _post('b'), _post('c')]);
      final n = FeedPagedNotifier(({cursor}) async => first);
      await Future<void>.delayed(Duration.zero);
      first = FeedPage(items: [_post('a'), _post('c')]);
      await n.refresh();
      expect(_ids(n), ['a', 'c']);
    });
  });

  test('an edit refreshes a paged feed without rebuilding it', () async {
    var fetches = 0;
    final feed = StateNotifierProvider<FeedPagedNotifier,
        AsyncValue<FeedPagedState>>((ref) => FeedPagedNotifier(({cursor}) async {
          fetches++;
          return FeedPage(items: [_post('a')]);
        }));
    final container = ProviderContainer(
      observers: [EditRefreshObserver(include: {feed})],
    );
    addTearDown(container.dispose);
    container.listen(feed, (_, __) {});
    final before = container.read(feed.notifier);
    await Future<void>.delayed(Duration.zero);

    container.read(dataEditEpochProvider.notifier).state++;
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(identical(container.read(feed.notifier), before), isTrue,
        reason: 'rebuilding the notifier dropped every loaded page');
    expect(fetches, 2);
  });

  group('no screen blanks itself while reloading', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    test('every AsyncValue.when with a loading branch skips it on reload', () {
      final offenders = <String>[];
      for (final f in files) {
        final s = f.readAsStringSync();
        // Comments are dropped so an apostrophe in one cannot hide a call.
        final code = s.replaceAll(RegExp(r'//[^\n]*'), '');
        for (final m in RegExp(r'\.when\(').allMatches(code)) {
          var depth = 1;
          var j = m.end;
          while (j < code.length && depth > 0) {
            if (code[j] == '(') depth++;
            if (code[j] == ')') depth--;
            j++;
          }
          final call = code.substring(m.end, j);
          if (RegExp(r'(^|[\s,(])loading\s*:').hasMatch(call) &&
              !call.contains('skipLoadingOnReload')) {
            offenders.add('${f.path}:'
                '${'\n'.allMatches(code.substring(0, m.start)).length + 1}');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('a FutureBuilder waits only when it has nothing to show', () {
      final offenders = <String>[];
      final bare = RegExp(
          r'(snap|snapshot)\.connectionState != ConnectionState\.done\)');
      for (final f in files) {
        if (bare.hasMatch(f.readAsStringSync())) offenders.add(f.path);
      }
      expect(offenders, isEmpty);
    });
  });
}
