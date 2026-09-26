import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/me/data/search_listing_repository.dart';
import 'package:aura/features/me/presentation/search_listing_screen.dart';

/// Search listing is the person's choice (founder ruling 2026-09-26): off
/// unless chosen, and a failed load is never shown as "off".
class _FakeRepo extends SearchListingRepository {
  _FakeRepo({required this.initial, this.fail = false}) : super(Dio());

  SearchListing initial;
  final bool fail;
  final List<bool> sets = [];

  @override
  Future<SearchListing> get() async {
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/x'));
    return initial;
  }

  @override
  Future<SearchListing> set({required bool listed}) async {
    sets.add(listed);
    initial = SearchListing(listed: listed, since: listed ? DateTime(2026) : null);
    return initial;
  }
}

Widget _app(_FakeRepo repo) => ProviderScope(
      overrides: [searchListingRepositoryProvider.overrideWithValue(repo)],
      // The app shell supplies the Scaffold (AuraScaffold deliberately does
      // not), so the test mounts the screen inside one, as the shell does.
      child: const MaterialApp(home: Scaffold(body: SearchListingScreen())),
    );

void main() {
  testWidgets('shows the choice as OFF when the person never chose', (t) async {
    final repo = _FakeRepo(initial: const SearchListing(listed: false));
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();

    final sw = t.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(sw.value, isFalse);
    expect(find.textContaining('not in Aura\'s sitemap'), findsOneWidget);
    // It says plainly what it does not do.
    expect(find.textContaining('does not make your profile private'), findsOneWidget);
  });

  testWidgets('turning it on asks the server, and says so', (t) async {
    final repo = _FakeRepo(initial: const SearchListing(listed: false));
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();

    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();

    expect(repo.sets, [true]);
    expect(find.textContaining('will be included'), findsOneWidget);
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
  });

  testWidgets('while loading it says what it is loading', (t) async {
    final repo = _FakeRepo(initial: const SearchListing(listed: false));
    await t.pumpWidget(_app(repo));
    // First frame, before the fake answers.
    expect(find.text('Checking your search engine setting.'), findsOneWidget);
    expect(find.textContaining('people ready'), findsNothing);
    await t.pumpAndSettle();
  });

  testWidgets('a failed load is an error, never a switch showing OFF', (t) async {
    final repo = _FakeRepo(initial: const SearchListing(listed: false), fail: true);
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsNothing);
  });

  test('only an explicit true from the server counts as listed', () {
    expect(SearchListing.fromJson({'listed': true, 'since': '2026-09-26T00:00:00.000Z'}).listed, isTrue);
    expect(SearchListing.fromJson({'listed': 'true'}).listed, isFalse);
    expect(SearchListing.fromJson(null).listed, isFalse);
    expect(SearchListing.fromJson({'listed': false, 'since': '2026-09-26'}).since, isNull);
  });
}
