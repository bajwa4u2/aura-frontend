import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feed/data/unified_feed_providers.dart';
import '../../features/posts/data/reactions_repository.dart';
import '../../features/posts/presentation/widgets/post_card.dart' show isSavedProvider;
import '../../features/saves/providers.dart';
import '../../features/updates/incoming_call_bridge.dart';
import '../../features/updates/providers.dart' show notificationsControllerProvider;
import '../interactions/follows_repository.dart' show followStateProvider;

/// R5 — Cross-device canonical reconciliation on notification open.
///
/// When the user taps a notification (either inside the app or from a
/// system push), they expect the landing surface to reflect *current*
/// backend truth — not stale local cache. Without this helper:
///   * Tapping a REPLY notification after backgrounding for ten minutes
///     can land on a feed-item detail screen whose cached provider
///     still shows yesterday's reply count.
///   * Tapping a FOLLOW notification can land on a profile whose
///     follow-button cache hasn't observed the new state.
///   * Tapping a MISSED-CALL notification after the originating call
///     already ended elsewhere can leave the ringing card visible.
///
/// The helper accepts whatever notification shape is in hand
/// ([AppNotification]-style typed row OR an FCM payload map) and
/// flushes the canonical Riverpod providers for the affected surface.
/// Navigation happens BEFORE this call returns, so the user sees the
/// landing screen with a loading shimmer rather than stale data.
///
/// All invalidations are wrapped in try/catch — a missing provider or
/// disposed container must never block the navigation that just
/// happened. Targets that 404 are surfaced by the landing screen's
/// own error state, not by this helper.
class NotificationOpenReconcile {
  NotificationOpenReconcile._();

  /// Map an FCM-style payload (the same shape the system push handler
  /// sees) to the right invalidations.
  static void onFcmTap(WidgetRef ref, Map<String, dynamic> payload) {
    final type = _readString(payload, const ['type', 'notificationKind', 'kind'])
        .toUpperCase();
    final postId = _readString(payload, const ['postId', 'institutionPostId']);
    final threadId = _readString(payload, const ['directThreadId', 'threadId']);
    final sessionId = _readString(payload, const [
      'realtimeSessionId',
      'sessionId',
    ]);
    _reconcile(
      ref: ref,
      type: type,
      postId: postId,
      threadId: threadId,
      sessionId: sessionId,
    );
  }

  /// Map a typed [AppNotification]-style row (in-app tap path) to the
  /// right invalidations. Callers pass the discrete fields so we don't
  /// have to import the model into core/.
  static void onAppTap(
    WidgetRef ref, {
    required String type,
    String? postId,
    String? institutionPostId,
    String? directThreadId,
  }) {
    _reconcile(
      ref: ref,
      type: type.toUpperCase(),
      postId: (postId ?? institutionPostId ?? '').trim(),
      threadId: (directThreadId ?? '').trim(),
      sessionId: '',
    );
  }

  static void _reconcile({
    required WidgetRef ref,
    required String type,
    required String postId,
    required String threadId,
    required String sessionId,
  }) {
    try {
      // Notifications themselves: the list and unread count must reflect
      // the just-read state. The controller already markRead's the row,
      // but a stale cache window can show the unread badge for a few
      // seconds longer — forcing a refresh closes that gap.
      ref.invalidate(notificationsControllerProvider);
    } catch (_) {}

    switch (type) {
      case 'LIKE':
      case 'REPLY':
      case 'REPOST':
      case 'MENTION':
      case 'THREAD_ACTIVITY':
        _invalidatePostSurfaces(ref);
        break;
      case 'SAVE':
        _invalidatePostSurfaces(ref);
        _invalidateSaveSurfaces(ref, postId: postId);
        break;
      case 'FOLLOW':
      case 'FOLLOW_REQUEST':
      case 'FOLLOW_ACCEPTED':
        _invalidateFollowSurfaces(ref);
        break;
      case 'MESSAGE':
      case 'SPACE_INVITE':
      case 'THREAD_INVITE':
      case 'INVITE_ACCEPTED':
      case 'SPACE_ACTIVITY':
        _invalidateFeedSurfaces(ref);
        break;
      case 'CALL_INCOMING':
      case 'CALL_MISSED':
      case 'CALL_CANCELLED':
      case 'CALL_ENDED':
      case 'LIVE':
      case 'CALL':
      case 'REALTIME':
        _invalidateCallSurfaces(ref);
        break;
      case 'ACCOUNTABILITY_TAGGED':
      case 'PRIORITY_PINNED':
      case 'POST_PUBLISHED':
      case 'POST_PUBLISH_FAILED':
        _invalidatePostSurfaces(ref);
        break;
      default:
        // Unknown / new types: a conservative feed-surface flush is
        // safer than no flush. The detail screen will refetch on next
        // watch. Don't touch the call bridge — call types are rare.
        _invalidateFeedSurfaces(ref);
        break;
    }
  }

  static void _invalidatePostSurfaces(WidgetRef ref) {
    try {
      ref.invalidate(reactionStateProvider);
    } catch (_) {}
    _invalidateFeedSurfaces(ref);
  }

  static void _invalidateFeedSurfaces(WidgetRef ref) {
    try {
      ref.invalidate(globalPublicFeedProvider);
      ref.invalidate(memberHomeFeedProvider);
      ref.invalidate(institutionExploreFeedProvider);
      ref.invalidate(institutionProfileFeedProvider);
      ref.invalidate(feedItemDetailProvider);
      ref.invalidate(feedItemRepliesProvider);
      ref.invalidate(globalPublicFeedPagedProvider);
      ref.invalidate(memberHomeFeedPagedProvider);
      ref.invalidate(institutionExploreFeedPagedProvider);
      ref.invalidate(institutionProfileFeedPagedProvider);
    } catch (_) {}
  }

  static void _invalidateSaveSurfaces(WidgetRef ref, {required String postId}) {
    try {
      ref.invalidate(savedPostsProvider);
      if (postId.isNotEmpty) {
        ref.invalidate(isSavedProvider(postId));
      } else {
        ref.invalidate(isSavedProvider);
      }
    } catch (_) {}
  }

  static void _invalidateFollowSurfaces(WidgetRef ref) {
    try {
      ref.invalidate(followStateProvider);
    } catch (_) {}
    _invalidateFeedSurfaces(ref);
  }

  static void _invalidateCallSurfaces(WidgetRef ref) {
    // Drop any ringing card whose backend session is already resolved.
    // The bridge's evictExpired() handles TTL-based eviction; for an
    // explicit terminal payload we know the session is over, so we
    // mirror the bridge.onSessionTerminated path defensively. The
    // bridge already de-dupes by sessionId, so an extra eviction pass
    // is a no-op when state is already clean.
    try {
      final bridge = ref.read(incomingCallBridgeProvider.notifier);
      bridge.evictExpired();
    } catch (_) {}
  }

  static String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }
}
