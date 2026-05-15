import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/notifications/notification_open_reconcile.dart';

/// R5 — Smoke coverage for `NotificationOpenReconcile`. The helper is a
/// pure invalidator (no return value); the only legitimate failure mode
/// is throwing. These tests assert that for every notification type +
/// stale-target shape we recognise, the helper runs without raising.
///
/// Provider observation is intentionally NOT mocked: the helper guards
/// every `ref.invalidate` in try/catch so the worst case for an unknown
/// provider edge is silent. The contract we're protecting is "never
/// crash the navigation that's about to happen."

WidgetRef _ref(WidgetTester tester) {
  // Build a minimal widget that exposes a WidgetRef from inside the
  // ProviderScope. The test asserts that the helper accepts the ref
  // without throwing, then returns the ref to the caller.
  late WidgetRef capturedRef;
  tester.binding.runAsync(() async {
    return tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
  return capturedRef;
}

void main() {
  testWidgets('helper tolerates every known notification type without throwing',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            for (final type in const <String>[
              'LIKE',
              'REPLY',
              'REPOST',
              'MENTION',
              'THREAD_ACTIVITY',
              'SAVE',
              'FOLLOW',
              'FOLLOW_REQUEST',
              'FOLLOW_ACCEPTED',
              'MESSAGE',
              'SPACE_INVITE',
              'THREAD_INVITE',
              'INVITE_ACCEPTED',
              'SPACE_ACTIVITY',
              'CALL_INCOMING',
              'CALL_MISSED',
              'CALL_CANCELLED',
              'ACCOUNTABILITY_TAGGED',
              'PRIORITY_PINNED',
              'POST_PUBLISHED',
              'POST_PUBLISH_FAILED',
            ]) {
              expect(
                () => NotificationOpenReconcile.onAppTap(
                  ref,
                  type: type,
                  postId: 'p1',
                  institutionPostId: null,
                  directThreadId: 'thr1',
                ),
                returnsNormally,
                reason: 'type=$type must not throw',
              );
            }

            // Unknown type — falls through to the default feed-flush
            // path; still must not throw.
            expect(
              () => NotificationOpenReconcile.onAppTap(
                ref,
                type: 'FUTURE_TYPE_NOT_YET_DEFINED',
                postId: '',
              ),
              returnsNormally,
            );

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('FCM tap handles stale / partial payloads safely',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            // Empty payload — unknown type, no ids. Should still run
            // through the default fall-through branch.
            expect(
              () => NotificationOpenReconcile.onFcmTap(
                ref,
                <String, dynamic>{},
              ),
              returnsNormally,
            );

            // Stale-target payload: post id points at a now-deleted
            // post. Helper has no way to verify existence; the landing
            // screen surfaces 404 via the provider's own error state.
            // The helper itself must not block the navigation.
            expect(
              () => NotificationOpenReconcile.onFcmTap(
                ref,
                <String, dynamic>{
                  'type': 'REPLY',
                  'postId': 'deleted-post-id',
                  'deeplink': '/posts/deleted-post-id',
                },
              ),
              returnsNormally,
            );

            // Mixed casing — accepts both legacy `deepLink` and
            // canonical `deeplink` shapes.
            expect(
              () => NotificationOpenReconcile.onFcmTap(
                ref,
                <String, dynamic>{
                  'type': 'CALL_MISSED',
                  'realtimeSessionId': 'sess-1',
                  'deepLink': '/realtime/sess-1',
                },
              ),
              returnsNormally,
            );

            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // Suppress unused-ref-helper warning if the helper changes.
    expect(_ref, isNotNull);
  });
}
