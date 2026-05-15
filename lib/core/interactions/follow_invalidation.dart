import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feed/data/unified_feed_providers.dart';
import 'follows_repository.dart';

/// Centralised follow-graph invalidation.
///
/// Called after a successful follow/unfollow so every canonical surface
/// that depends on the follow graph re-fetches on next watch:
///   * the actor-aware per-pair state cache (`followStateProvider`)
///   * every unified feed surface (public home, member home, institution
///     explore, institution profile, post detail) — follow graph changes
///     are visible immediately on the home feed instead of forcing the
///     user to navigate away and back.
///
/// `key` identifies the precise (actor, target) pair that was mutated.
/// Pass null when the mutation went through a non-actor-aware legacy
/// endpoint (e.g. `users.controller`'s `/follow/request`) — the per-pair
/// cache is then left untouched and the actor-state probe re-fetches on
/// next watch on its own.
void invalidateFollowSurfaces(
  WidgetRef ref, {
  FollowStateKey? key,
}) {
  if (key != null) {
    ref.invalidate(followStateProvider(key));
  }
  invalidateUnifiedFeedSurfaces(ref);
}
