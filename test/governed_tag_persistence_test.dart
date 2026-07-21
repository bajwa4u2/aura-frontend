import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/tagging/tag_entities.dart';
import 'package:aura/features/public/widgets/mention_text.dart';

void main() {
  test('TagReference serializes durable entity metadata', () {
    const reference = TagReference(
      kind: TagKind.member,
      canonicalId: 'user-1',
      entityId: 'user-1',
      display: 'Muhammad S. Bajwa',
      insertText: '@msbajwa',
      sourceText: '@msbajwa',
      startOffset: 6,
      endOffset: 14,
    );

    expect(reference.toJson(), containsPair('kind', 'member'));
    expect(reference.toJson(), containsPair('entityId', 'user-1'));
    expect(
      reference.toJson(),
      containsPair('displayLabel', 'Muhammad S. Bajwa'),
    );
    expect(reference.toJson(), containsPair('sourceText', '@msbajwa'));
    expect(reference.toJson(), containsPair('startOffset', 6));
    expect(reference.toJson(), containsPair('endOffset', 14));
  });

  test('TagReference hydrates resolved identity from read payload', () {
    final reference = TagReference.fromJson(const <String, dynamic>{
      'kind': 'institution',
      'entityId': 'inst-1',
      'displayLabel': 'Historical Name',
      'sourceText': '@old-name',
      'identity': <String, dynamic>{
        'id': 'inst-1',
        'type': 'institution',
        'displayLabel': 'Current Institution Name',
        'handleOrSlug': 'current-institution',
        'route': '/institutions/current-institution',
      },
    });

    expect(reference.kind, TagKind.institution);
    expect(reference.durableEntityId, 'inst-1');
    expect(reference.displayLabel, 'Current Institution Name');
    expect(reference.identity?.route, '/institutions/current-institution');
  });

  testWidgets('ResolvedTagText opens member and institution references', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const _TagHarness()),
        GoRoute(
          path: '/u/:handle',
          builder: (_, state) =>
              Text('member:${state.pathParameters['handle']}'),
        ),
        GoRoute(
          path: '/institutions/:slug',
          builder: (_, state) =>
              Text('institution:${state.pathParameters['slug']}'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.textContaining('@Muhammad'), findsOneWidget);
    expect(find.textContaining('@msbajwa'), findsNothing);
    await tester.tap(find.textContaining('@Muhammad'));
    await tester.pumpAndSettle();
    expect(find.text('member:msbajwa'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    expect(find.textContaining('@Aura Institute'), findsOneWidget);
    expect(find.textContaining('@aura-institute'), findsNothing);
    await tester.tap(find.textContaining('@Aura Institute'));
    await tester.pumpAndSettle();
    expect(find.text('institution:aura-institute'), findsOneWidget);
  });
}

class _TagHarness extends StatelessWidget {
  const _TagHarness();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ResolvedTagText(
        'Talk to @msbajwa at @aura-institute',
        tagReferences: [
          TagReference(
            kind: TagKind.member,
            canonicalId: 'user-1',
            entityId: 'user-1',
            display: 'Muhammad',
            insertText: '@msbajwa',
            sourceText: '@msbajwa',
            startOffset: 8,
            endOffset: 16,
            identity: TagIdentity(
              id: 'user-1',
              type: 'member',
              displayLabel: 'Muhammad',
              handleOrSlug: 'msbajwa',
              route: '/u/msbajwa',
            ),
          ),
          TagReference(
            kind: TagKind.institution,
            canonicalId: 'inst-1',
            entityId: 'inst-1',
            display: 'Aura Institute',
            insertText: '@aura-institute',
            sourceText: '@aura-institute',
            startOffset: 20,
            endOffset: 35,
            identity: TagIdentity(
              id: 'inst-1',
              type: 'institution',
              displayLabel: 'Aura Institute',
              handleOrSlug: 'aura-institute',
              route: '/institutions/aura-institute',
            ),
          ),
        ],
      ),
    );
  }
}
