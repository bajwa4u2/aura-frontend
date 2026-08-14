import 'package:aura/core/tagging/governed_tag_field.dart';
import 'package:aura/core/tagging/mention_scope.dart';
import 'package:aura/core/tagging/tag_entities.dart';
import 'package:aura/features/search/providers.dart';
import 'package:aura/features/search/search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Domain 9 — Mention Target Eligibility, frontend contextual coherence.
// Proves GovernedTagAutocomplete under MentionScope.bounded (a) only ever
// offers the caller-supplied eligible set, filtered locally, (b) never
// calls the global /search endpoint at all, and (c) MentionScope.global
// (the default, used by Posts/Institution Posts/Announcements/replies)
// keeps calling it exactly as before -- so bounded surfaces can never
// offer a contextually ineligible target, and global surfaces are
// provably unaffected by this file's existence.

class _ExplodingSearchRepository extends SearchRepository {
  _ExplodingSearchRepository() : super(Dio());

  @override
  Future<SearchResult> search(String q, {int limit = 12}) async {
    fail('bounded MentionScope must never call the global /search endpoint');
  }
}

class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository() : super(Dio());

  @override
  Future<SearchResult> search(String q, {int limit = 12}) async {
    return const SearchResult(
      users: [
        {'id': 'global-1', 'handle': 'globaluser', 'displayName': 'Global User'},
      ],
      institutions: [],
      posts: [],
    );
  }
}

const _boundedCandidates = [
  TagSuggestion(
    kind: TagKind.member,
    canonicalId: 'member-1',
    display: 'Amina Bajwa',
    insertText: '@Amina Bajwa',
    subtitle: '@amina',
  ),
  TagSuggestion(
    kind: TagKind.institution,
    canonicalId: 'inst-1',
    display: 'CivicOrg',
    insertText: '@CivicOrg',
    subtitle: '@civicorg · Institution',
  ),
];

Widget _harness({
  required TextEditingController controller,
  required FocusNode focusNode,
  required MentionScope scope,
  required SearchRepository searchRepository,
}) {
  return ProviderScope(
    overrides: [
      searchRepositoryProvider.overrideWithValue(searchRepository),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: GovernedTagAutocomplete(
          controller: controller,
          focusNode: focusNode,
          mentionScope: scope,
          child: TextField(controller: controller, focusNode: focusNode, maxLines: null),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('bounded scope offers only the supplied eligible candidates, filtered locally, no network call', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      _harness(
        controller: controller,
        focusNode: focusNode,
        scope: const MentionScope.bounded(_boundedCandidates),
        searchRepository: _ExplodingSearchRepository(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hi @');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Amina Bajwa'), findsOneWidget);
    expect(find.text('CivicOrg'), findsOneWidget);
  });

  testWidgets('bounded scope never offers a candidate outside the eligible set, even matching global search data', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      _harness(
        controller: controller,
        focusNode: focusNode,
        scope: const MentionScope.bounded(_boundedCandidates),
        searchRepository: _ExplodingSearchRepository(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hi @glob');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Global User'), findsNothing);
  });

  testWidgets('bounded scope substring-filters as the query narrows', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      _harness(
        controller: controller,
        focusNode: focusNode,
        scope: const MentionScope.bounded(_boundedCandidates),
        searchRepository: _ExplodingSearchRepository(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hi @civ');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('CivicOrg'), findsOneWidget);
    expect(find.text('Amina Bajwa'), findsNothing);
  });

  testWidgets('global scope (the default) keeps calling live /search unaffected', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      _harness(
        controller: controller,
        focusNode: focusNode,
        scope: const MentionScope.global(),
        searchRepository: _FakeSearchRepository(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hi @glob');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Global User'), findsOneWidget);
  });
}
