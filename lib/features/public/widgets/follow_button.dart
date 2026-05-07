import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _toggle(bool currentlyFollowing) async {
    if (_busy) return;
    setState(() => _busy = true);
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
      // Errors are surfaced via the existing global error handler;
      // we just unblock the button so the user can retry.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncFollowing = widget._isThread
        ? ref.watch(threadFollowingProvider(widget.threadPostId!))
        : ref.watch(spaceFollowingProvider(widget.spaceSlug!));

    final following = asyncFollowing.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
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
