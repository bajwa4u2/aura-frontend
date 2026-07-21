import 'package:aura/core/tagging/governed_tag_field.dart';
import 'package:aura/core/tagging/tag_entities.dart';
import 'package:aura/features/search/providers.dart';
import 'package:aura/features/search/search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository() : super(Dio());

  @override
  Future<SearchResult> search(String q, {int limit = 12}) async {
    return const SearchResult(
      users: [
        {
          'id': 'user-2',
          'handle': 'neighbor',
          'displayName': 'Neighbor Person',
          'avatarUrl': 'https://cdn.example.com/avatar.png',
        },
      ],
      institutions: [
        {
          'id': 'inst-1',
          'slug': 'aura-platform',
          'name': 'Aura Platform',
          'logoUrl': 'https://cdn.example.com/logo.png',
        },
      ],
      posts: [],
    );
  }
}

Widget _harness({
  required TextEditingController controller,
  required FocusNode focusNode,
  required ValueChanged<TagReference> onSelected,
}) {
  return ProviderScope(
    overrides: [
      searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: GovernedTagAutocomplete(
          controller: controller,
          focusNode: focusNode,
          onTagSelected: onSelected,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: null,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tap selection inserts mention text and records canonical id', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final selected = <TagReference>[];

    await tester.pumpWidget(
      _harness(
        controller: controller,
        focusNode: focusNode,
        onSelected: selected.add,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hello @nei');
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Neighbor Person'));
    await tester.pump();

    expect(controller.text, 'Hello @neighbor ');
    expect(selected.single.kind, TagKind.member);
    expect(selected.single.canonicalId, 'user-2');
    expect(selected.single.insertText, '@neighbor');
  });

  testWidgets('keyboard selection inserts highlighted mention', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final selected = <TagReference>[];

    await tester.pumpWidget(
      _harness(
        controller: controller,
        focusNode: focusNode,
        onSelected: selected.add,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hello @nei');
    await tester.pump(const Duration(milliseconds: 200));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'Hello @neighbor ');
    expect(selected.single.canonicalId, 'user-2');
  });
}
