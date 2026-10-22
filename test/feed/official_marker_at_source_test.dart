import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/features/feed/data/unified_feed_providers.dart';
import 'package:aura/features/feed/domain/feed_item.dart';
import 'package:aura/features/home/presentation/public_home_screen.dart';
import 'package:aura/features/institutions/domain/communication_type.dart';
import 'package:aura/features/institutions/domain/institution_post.dart';
import 'package:aura/features/institutions/live_rooms/global_live_discovery.dart';
import 'package:aura/features/public/data/public_spaces_repository.dart';

/// The stored "[OFFICIAL:TYPE]" title marker never reaches a surface.
///
/// 21 Oct 2026: the public home card ("ON THE PUBLIC RECORD NOW") showed
/// "[OFFICIAL:UPDATE] THE WORKSHOP, our company film…" raw, because only a
/// few surfaces decoded the marker and the rest rendered the stored title.
/// The marker is now removed where post data is read, and the official type
/// travels as its own field.
///
/// The payload follows the backend's FeedProjectionService.fromInstitutionPost
/// (type INSTITUTION_POST, authorType INSTITUTION, institutionAuthor fields).
Map<String, dynamic> institutionPostPayload({
  String title = '[OFFICIAL:UPDATE] THE WORKSHOP, our company film.',
  String type = 'INSTITUTION_POST',
  String authorType = 'INSTITUTION',
}) =>
    <String, dynamic>{
      'id': 'ip-1',
      'type': type,
      'authorType': authorType,
      'author': <String, dynamic>{
        'id': 'inst-1',
        'type': authorType,
        'name': 'Aura Platform LLC',
        'handleOrSlug': 'aura-platform-llc',
        'avatarOrLogoUrl': null,
        'profileRoute': '/institutions/aura-platform-llc',
        'context': <String, dynamic>{
          'type': 'OFFICIAL_INSTITUTION',
          'label': 'Verified institution',
        },
      },
      'title': title,
      'body': 'Products leave the bench: they are licensed, they may change hands.',
      'mediaUrl': null,
      'media': const <dynamic>[],
      'visibility': 'PUBLIC',
      'distribution': 'GLOBAL_ELIGIBLE',
      'status': 'PUBLISHED',
      'primaryTopic': null,
      'secondaryTopics': const <dynamic>[],
      'tagReferences': const <dynamic>[],
      'createdAt': '2026-10-14T13:00:00.000Z',
      'publishedAt': '2026-10-14T13:00:00.000Z',
      'targetRoute': '/institution/aura-platform-llc/posts/ip-1',
      'interaction': const <String, dynamic>{},
    };

void main() {
  group('decoded where the post is read', () {
    test('an institution post: clean title, official type kept', () {
      final item = FeedItem.fromJson(institutionPostPayload());
      expect(item.title, 'THE WORKSHOP, our company film.');
      expect(item.officialType, InsCommunicationType.update);
      expect(item.communication.hadMarker, isTrue);
      expect(item.communication.cleanTitle, item.title);
    });

    test('each type decodes to its own field', () {
      for (final t in InsCommunicationType.values) {
        final item = FeedItem.fromJson(
          institutionPostPayload(title: '[OFFICIAL:${t.wire}] Words'),
        );
        expect(item.title, 'Words');
        expect(item.officialType, t);
      }
    });

    test('an unmarked institution post has no official type', () {
      final item = FeedItem.fromJson(institutionPostPayload(title: 'Plain'));
      expect(item.title, 'Plain');
      expect(item.officialType, isNull);
      expect(item.communication.hadMarker, isFalse);
    });

    test('a personal post cannot claim to be official', () {
      final item = FeedItem.fromJson(institutionPostPayload(
        title: '[OFFICIAL:ADVISORY] Not official',
        type: 'POST',
        authorType: 'USER',
      ));
      expect(item.title, 'Not official');
      expect(item.officialType, isNull);
    });

    test('an institution post model keeps the type through a round trip', () {
      final post = InstitutionPost.fromJson(<String, dynamic>{
        'id': 'ip-1',
        'institutionId': 'inst-1',
        'authorUserId': 'u-1',
        'title': '[OFFICIAL:ADVISORY] Water notice',
        'body': 'Boil water until Friday.',
        'visibility': 'PUBLIC',
        'distribution': 'GLOBAL_ELIGIBLE',
        'status': 'PUBLISHED',
      });
      expect(post.title, 'Water notice');
      expect(post.officialType, InsCommunicationType.advisory);
      expect(post.communication.type, InsCommunicationType.advisory);
      expect(post.toJson()['title'], '[OFFICIAL:ADVISORY] Water notice');
    });
  });

  testWidgets('the public home card shows the words and the official type',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final item = FeedItem.fromJson(institutionPostPayload());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isAuthedProvider.overrideWithValue(false),
        globalPublicFeedProvider
            .overrideWith((ref) async => FeedPage(items: [item])),
        globalDiscoverableLiveProvider.overrideWith((ref) async => const []),
        publicSpacesListProvider.overrideWith((ref) async => const []),
      ],
      // The page sits inside the shell's Scaffold in the app.
      child: const MaterialApp(home: Scaffold(body: PublicHomeScreen())),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('[OFFICIAL:'), findsNothing);
    expect(find.textContaining('THE WORKSHOP, our company film.'), findsWidgets);
    expect(find.text('OFFICIAL UPDATE'), findsOneWidget);
  });
}
