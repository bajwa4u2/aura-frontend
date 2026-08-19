// BOTH ENGAGEMENT SCREENS MUST RENDER THE POST.
//
// The producer/consumer mismatch was invisible precisely because both screens
// guard the content with `if (content.isNotEmpty)`. A wrong field name did not
// throw and did not show a placeholder — the post simply was not there. Model
// tests alone would not have caught that, so these drive the real screens with
// the real producer payload and assert the content is on the screen.
//
// The list truncates (maxLines: 3, ellipsis) and the detail shows the whole
// post. That presentation difference is deliberate and preserved; what must be
// shared is the SOURCE.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/institutions/engagement/engagement_detail_screen.dart';
import 'package:aura/features/institutions/engagement/engagement_list_screen.dart';
import 'package:aura/features/institutions/engagement/engagement_models.dart';
import 'package:aura/features/institutions/engagement/engagement_providers.dart';

const _postText = 'What is your policy on winter closures?';

RoutedRecord _record() => RoutedRecord.fromJson(const {
      'id': 'rec-1',
      'status': 'PENDING',
      'routedAt': '2026-06-20T10:00:00.000Z',
      'topic': 'GOVERNMENT',
      'participationMode': 'RESPONDING',
      'post': {
        'id': 'post-1',
        'text': _postText,
        'intent': 'ASK',
        'primaryTopic': 'GOVERNMENT',
        'jurisdictionId': 'jur-1',
        'createdAt': '2026-06-20T09:00:00.000Z',
        'author': {
          'id': 'u-1',
          'handle': 'alice',
          'displayName': 'Alice',
          'avatarUrl': null,
        },
      },
    });

Widget _harness(Widget child, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      // AuraScaffold defers its Material to the app shell, so the harness
      // supplies one — otherwise the record tiles' InkWell has no ancestor.
      child: MaterialApp(home: Material(child: child)),
    );

void main() {
  testWidgets('the engagement LIST renders the routed post content', (tester) async {
    await tester.pumpWidget(_harness(
      const EngagementListScreen(institutionId: 'inst-1'),
      [
        engagementListProvider('inst-1').overrideWith((ref) async => [_record()]),
        engagementSummaryProvider('inst-1').overrideWith(
          (ref) async => EngagementSummary.fromJson(const {
            'total': 1,
            'needsResponse': 1,
            'byTopic': <String, dynamic>{},
            'byIntent': <String, dynamic>{},
          }),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text(_postText), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('the engagement DETAIL renders the same routed post content',
      (tester) async {
    await tester.pumpWidget(_harness(
      const EngagementDetailScreen(institutionId: 'inst-1', recordId: 'rec-1'),
      [
        engagementDetailProvider(('inst-1', 'rec-1'))
            .overrideWith((ref) async => _record()),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text(_postText), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('a record whose post the producer left empty shows no content '
      'block — and no invented placeholder', (tester) async {
    final empty = RoutedRecord.fromJson(const {
      'id': 'rec-2',
      'status': 'PENDING',
      'post': {'id': 'post-2', 'text': null},
    });

    await tester.pumpWidget(_harness(
      const EngagementDetailScreen(institutionId: 'inst-1', recordId: 'rec-2'),
      [
        engagementDetailProvider(('inst-1', 'rec-2'))
            .overrideWith((ref) async => empty),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text(_postText), findsNothing);
    // The absence is the producer's truth, not a placeholder standing in for a
    // contract the client failed to read.
    expect(find.textContaining('No content'), findsNothing);
  });
}
