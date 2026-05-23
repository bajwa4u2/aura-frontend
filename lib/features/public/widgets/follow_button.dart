import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../data/thread_space_follow_repository.dart';

/// Public-UX Phase 6.1 — follow toggle button.
///
/// Used in two surfaces:
///   * `FollowButton.thread(postId: ...)` on the ThreadScreen header.
///   * `FollowButton.space(slug: ...)` on the SpaceDetail mode header.
///
/// State sourced from `threadFollowingProvider` / `spaceFollowingProvider`.
/// Tap toggles via the repo, then invalidates the provider so the
/// label flips immediately. Disabled while in flight.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton.thread({super.key, required this.threadPostId})
      : spaceSlug = null,
        _isThread = true;

  const FollowButton.space({super.key, required this.spaceSlug})
      : threadPostId = null,
        _isThread = false;

  final String? threadPostId;
  final String? spaceSlug;
  // ignore: unused_element_parameter
  final bool _isThread;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  // Optimistic follow override. Set the moment the user taps the
  // button; cleared once the canonical provider re-fetch completes or
  // on backend failure. Lets the label flip immediately instead of
  // waiting for the round-trip.
  bool? _optimisticFollowing;

  Future<void> _toggle(bool currentlyFollowing) async {
    if (_busy) return;
    // Signed-out: send the visitor to /login with a redirect back to
    // wherever they were. The toggle endpoint is auth-only; firing it
    // signed-out only produces a 401 that the UI cannot recover from.
    if (!ref.read(isAuthedProvider)) {
      final redirect = GoRouterState.of(context).uri.toString();
      context.go('/login?redirect=${Uri.encodeComponent(redirect)}');
      return;
    }
    final nextFollowing = !currentlyFollowing;
    setState(() {
      _busy = true;
      _optimisticFollowing = nextFollowing;
    });
    final repo = ref.read(threadSpaceFollowRepositoryProvider);
    try {
      if (widget._isThread) {
        final id = widget.threadPostId!;
        if (currentlyFollowing) {
          await repo.unfollowThread(id);
        } else {
          await repo.followThread(id);
        }
        ref.invalidate(threadFollowingProvider(id));
      } else {
        final slug = widget.spaceSlug!;
        if (currentlyFollowing) {
          await repo.unfollowSpace(slug);
        } else {
          await repo.followSpace(slug);
        }
        ref.invalidate(spaceFollowingProvider(slug));
      }
    } catch (_) {
      // Rollback: drop optimistic override so the button reverts to
      // the provider's truth (which never changed locally). Errors
      // continue to surface via the global error handler.
      if (mounted) setState(() => _optimisticFollowing = null);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          // Clear the override once the round-trip is done. The
          // provider re-fetch triggered by invalidate lands with the
          // authoritative truth on next watch.
          _optimisticFollowing = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncFollowing = widget._isThread
        ? ref.watch(threadFollowingProvider(widget.threadPostId!))
        : ref.watch(spaceFollowingProvider(widget.spaceSlug!));

    // `valueOrNull` preserves the previous value through an
    // AsyncLoading reload (Riverpod's copyWithPrevious). `maybeWhen`
    // does NOT — its `data` branch fires only for AsyncData, so a
    // reload landed on `orElse: () => false` and the button briefly
    // flipped back to "Follow" between the optimistic clear (in
    // `_toggle.finally`) and the provider refetch resolving. Same
    // symptom and same fix shape as the institution-detail
    // `stateAsync.when(skipLoadingOnReload: true, …)` change; here we
    // hit it through valueOrNull because the consumer uses
    // `maybeWhen`, which has no skipLoadingOnReload parameter.
    final providerFollowing = asyncFollowing.valueOrNull ?? false;
    final following = _optimisticFollowing ?? providerFollowing;
    final loading = asyncFollowing.isLoading || _busy;

    final label = widget._isThread
        ? (following ? 'Following discussion' : 'Follow discussion')
        : (following ? 'Following space' : 'Follow space');
    final icon = following
        ? Icons.notifications_active_rounded
        : Icons.notifications_none_rounded;

    if (following) {
      return AuraSecondaryButton(
        label: label,
        icon: icon,
        onPressed: loading ? null : () => _toggle(true),
      );
    }
    return AuraPrimaryButton(
      label: label,
      icon: icon,
      onPressed: loading ? null : () => _toggle(false),
    );
  }
}
