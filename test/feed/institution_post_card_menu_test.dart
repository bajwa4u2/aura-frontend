import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/feed/domain/feed_item.dart';
import 'package:aura/features/feed/presentation/unified_feed_card.dart';
import 'package:aura/features/posts/presentation/widgets/post_card.dart';

/// 10 Oct 2026: the "…" menu on an institution's own post in the feed
/// offered its operators only "Report". Those who govern the post now get the
/// Edit and Delete its own page gives them; everyone else keeps Report.
void main() {
  FeedItem institutionPost() => FeedItem.fromJson({
        'id': 'ip1',
        'type': 'INSTITUTION_POST',
        'authorType': 'INSTITUTION',
        'author': {
          'id': 'inst-1',
          'type': 'institution',
          'name': 'Aura Platform LLC',
          'handleOrSlug': 'aura-platform-llc',
        },
        'body': 'A work keeps its author.',
        'visibility': 'PUBLIC',
        'distribution': 'GLOBAL_ELIGIBLE',
        'status': 'PUBLISHED',
        'targetRoute': '/institutions/aura-platform-llc/posts/ip1',
        'interaction': <String, dynamic>{},
      });

  Future<List<String>> pumpCard(
    WidgetTester tester, {
    InstitutionIdentity? identity,
    List<String>? pushed,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              child: UnifiedFeedCard(
                item: institutionPost(),
                showInteractionBar: false,
                showReplyPreview: false,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/institution/:id/posts/:postId/edit',
          builder: (_, state) {
            pushed?.add(state.uri.path);
            return const Text('editor');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          viewerIdentityProvider.overrideWith((ref) async => null),
          institutionIdentityProvider.overrideWithValue(identity),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return pushed ?? const [];
  }

  testWidgets('an operator of the institution may edit or delete its post',
      (tester) async {
    final pushed = <String>[];
    await pumpCard(
      tester,
      identity: const InstitutionIdentity(
        id: 'inst-1',
        name: 'Aura Platform LLC',
        slug: 'aura-platform-llc',
        isAuthorizedSpeaker: true,
        capabilities: {'PUBLISH_OFFICIAL'},
        role: 'OWNER',
      ),
      pushed: pushed,
    );

    expect(find.byTooltip('Report or block'), findsNothing);
    await tester.tap(find.byTooltip('Manage this post'));
    await tester.pumpAndSettle();
    expect(find.text('Edit post'), findsOneWidget);
    expect(find.text('Delete post'), findsOneWidget);

    await tester.tap(find.text('Edit post'));
    await tester.pumpAndSettle();
    expect(pushed, ['/institution/inst-1/posts/ip1/edit']);
  });

  testWidgets('a member who may not speak for it still sees Report',
      (tester) async {
    await pumpCard(
      tester,
      identity: const InstitutionIdentity(
        id: 'inst-1',
        name: 'Aura Platform LLC',
        slug: 'aura-platform-llc',
        isAuthorizedSpeaker: false,
        capabilities: {},
        role: 'MEMBER',
      ),
    );
    expect(find.byTooltip('Manage this post'), findsNothing);
    expect(find.byTooltip('Report or block'), findsOneWidget);
  });

  testWidgets('an operator of another institution still sees Report',
      (tester) async {
    await pumpCard(
      tester,
      identity: const InstitutionIdentity(
        id: 'inst-2',
        name: 'Elsewhere',
        slug: 'elsewhere',
        isAuthorizedSpeaker: true,
        capabilities: {'PUBLISH_OFFICIAL'},
        role: 'OWNER',
      ),
    );
    expect(find.byTooltip('Manage this post'), findsNothing);
    expect(find.byTooltip('Report or block'), findsOneWidget);
  });

  testWidgets('a person with no institution sees Report', (tester) async {
    await pumpCard(tester);
    expect(find.byTooltip('Manage this post'), findsNothing);
    expect(find.byTooltip('Report or block'), findsOneWidget);
  });
}
