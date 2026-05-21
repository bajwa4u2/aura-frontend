import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interactions/follows_repository.dart' show followStateProvider;
import '../../correspondence/data/correspondence_live_service.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../posts/data/reactions_repository.dart';
import '../../posts/presentation/widgets/post_card.dart' show isSavedProvider;
import '../../saves/providers.dart';

/// R3 — Cross-device reconciliation bridge.
///
/// Subscribes to the correspondence socket and converts realtime events
/// into canonical-provider invalidations so a mutation on one session
/// converges on every other session of the same user.
///
/// Design:
///   * The backend is the truth source. Events are tiny triggers; the
///     listeners refetch via the unified feed / interaction providers
///     — they never mutate complex local state from a payload.
///   * Privacy is enforced server-side (saves/follows only fan out to
///     the actor's user room). The frontend treats every event as
///     authorized by the fact that it reached this socket.
///   * `socket:connected` is the reconnect-resume fallback. After any
///     reconnect we re-invalidate the canonical surfaces so the
///     missed-event window closes without manual refresh.
///   * App-lifecycle resume reuses the same fallback path: when the
///     app comes back to foreground, the socket will (re)connect and
///     fire `socket:connected`, which triggers the same invalidation.
///   * Light debounce: bursts of like/save toggles within 250ms
///     collapse into one invalidation pass per provider family, so
///     rapid events never thrash the UI or wedge the refresh loop.
class RealtimeReconciliationController {
  RealtimeReconciliationController(this._ref) {
    _attach();
  }

  final Ref _ref;
  StreamSubscription<CorrespondenceLiveEvent>? _subscription;
  Timer? _debouncedFeed;
  Timer? _debouncedFollow;
  Timer? _debouncedSaves;
  DateTime? _lastReconnectAt;

  void _attach() {
    // Touch the live service so it boots when this controller initialises.
    // ensureConnected() is idempotent and silently no-ops without a token,
    // so attaching this controller never forces an authenticated boot.
    final live = _ref.read(correspondenceLiveServiceProvider);
    unawaited(live.ensureConnected().catchError((_) {}));
    _subscription = live.events.listen(_handle);
  }

  void _handle(CorrespondenceLiveEvent event) {
    switch (event.name) {
      case 'post:interaction.changed':
        _onPostInteractionChanged(event.payload);
        break;
      case 'follow:state.changed':
        _onFollowChanged(event.payload);
        break;
      case 'feed:item.changed':
        _scheduleFeedInvalidation();
        break;
      case 'socket:connected':
        _onReconnect();
        break;
    }
  }

  void _onPostInteractionChanged(Map<String, dynamic> payload) {
    final interactionType = (payload['interactionType'] ?? '').toString();
    switch (interactionType) {
      case 'save':
        _scheduleSavesInvalidation(payload);
        break;
      case 'like':
      case 'reply':
      case 'repost':
        _scheduleFeedInvalidation();
        // Per-post reaction state lives on a family provider — flushing
        // the family root forces every watching widget (every list card,
        // every detail screen) to refetch on next watch. The like-count
        // badge then converges.
        _ref.invalidate(reactionStateProvider);
        break;
      default:
        // Unknown interaction types are ignored — older clients on a
        // newer server should not refresh-loop on shapes they don't
        // understand. Backend can extend the enum without breaking us.
        break;
    }
  }

  void _onFollowChanged(Map<String, dynamic> payload) {
    // Follow state is viewer-private; the server gates the fan-out to the
    // caller's own sessions (plus the target's room for member follows).
    // Whatever reaches us is authorized — schedule the standard
    // follow-graph invalidation, which fans out to every feed surface.
    _scheduleFollowInvalidation();
  }

  void _onReconnect() {
    // Suppress duplicate reconnect cascades that fire in quick succession
    // (e.g. transport upgrade nudges). 2 seconds is comfortably above
    // socket.io's transport-upgrade latency and well below any human
    // reconnect cadence.
    final now = DateTime.now();
    if (_lastReconnectAt != null &&
        now.difference(_lastReconnectAt!).inMilliseconds < 2000) {
      return;
    }
    _lastReconnectAt = now;

    // Resume-fallback: invalidate canonical surfaces so any events
    // missed while disconnected converge without manual refresh.
    _scheduleFeedInvalidation();
    _scheduleFollowInvalidation();
    _scheduleSavesInvalidation(const <String, dynamic>{});
    _ref.invalidate(reactionStateProvider);
  }

  void _scheduleFeedInvalidation() {
    _debouncedFeed?.cancel();
    _debouncedFeed = Timer(const Duration(milliseconds: 250), () {
      _debouncedFeed = null;
      // The exact same helper used by mutation sites — reuses one
      // invalidation list, no duplicate refresh systems.
      _invalidateUnifiedFeeds();
    });
  }

  void _scheduleFollowInvalidation() {
    _debouncedFollow?.cancel();
    _debouncedFollow = Timer(const Duration(milliseconds: 250), () {
      _debouncedFollow = null;
      // The shared helper invalidates every feed surface plus the
      // followStateProvider family (when a key is provided). The
      // realtime payload doesn't carry the actor pair, so we pass no
      // key — the per-pair entries refetch on next watch through the
      // unified feed invalidation downstream.
      _invalidateFollowGraph();
    });
  }

  void _scheduleSavesInvalidation(Map<String, dynamic> payload) {
    _debouncedSaves?.cancel();
    _debouncedSaves = Timer(const Duration(milliseconds: 250), () {
      _debouncedSaves = null;
      _ref.invalidate(savedPostsProvider);
      final postId = (payload['postId'] ?? '').toString().trim();
      if (postId.isNotEmpty) {
        _ref.invalidate(isSavedProvider(postId));
      } else {
        // Reconnect fallback path with no postId — invalidate the
        // family root so every watching card refetches.
        _ref.invalidate(isSavedProvider);
      }
      // Save toggles also surface as a bookmark badge on feed cards,
      // and the feed item detail provider re-hydrates the saved flag
      // through the canonical surface refresh.
      _invalidateUnifiedFeeds();
    });
  }

  /// Mirrors `invalidateUnifiedFeedSurfaces` so this controller can
  /// refresh every feed surface without holding a `WidgetRef`. The list
  /// is inlined to keep the dependency one-way.
  ///
  /// The two non-family paged feeds MUST be refreshed via
  /// `.notifier.refresh()`, never `invalidate`. Invalidating a mounted
  /// non-family `StateNotifierProvider` from this controller's `Ref`
  /// trips a Riverpod dependency assertion (`_debugAssertCanDependOn`)
  /// on the realtime-reconnect path. The family paged providers are
  /// invalidated as normal. This now matches `invalidateUnifiedFeedSurfaces`
  /// exactly — an earlier inline copy diverged and used `invalidate`
  /// for all four paged providers.
  void _invalidateUnifiedFeeds() {
    _ref.invalidate(globalPublicFeedProvider);
    _ref.invalidate(memberHomeFeedProvider);
    _ref.invalidate(institutionExploreFeedProvider);
    _ref.invalidate(institutionProfileFeedProvider);
    _ref.invalidate(feedItemDetailProvider);
    _ref.invalidate(feedItemRepliesProvider);
    _ref.read(globalPublicFeedPagedProvider.notifier).refresh();
    _ref.read(memberHomeFeedPagedProvider.notifier).refresh();
    _ref.invalidate(institutionExploreFeedPagedProvider);
    _ref.invalidate(institutionProfileFeedPagedProvider);
  }

  void _invalidateFollowGraph() {
    // Per-pair follow state cache + every feed surface (the follow
    // graph affects every list). `followStateProvider` is invalidated
    // at the family root so every key refetches on next watch.
    _ref.invalidate(followStateProvider);
    _invalidateUnifiedFeeds();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _debouncedFeed?.cancel();
    _debouncedFollow?.cancel();
    _debouncedSaves?.cancel();
  }
}

/// Eager-listened provider — read once from the app shell so the
/// controller boots, attaches its socket listener, and stays alive for
/// the app's lifetime. Reading is idempotent: the controller is
/// constructed once per ProviderScope.
final realtimeReconciliationProvider =
    Provider<RealtimeReconciliationController>((ref) {
  final controller = RealtimeReconciliationController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
