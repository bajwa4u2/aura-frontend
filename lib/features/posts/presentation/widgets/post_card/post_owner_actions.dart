/// WHAT AN AUTHOR MAY DO TO THEIR OWN POST — IN ONE PLACE.
///
/// Deleting a post was implemented inside `PostCard`, which is only rendered
/// on post detail, the author profile and saved. The feed renders
/// `UnifiedFeedCard`, which had no owner actions at all — so somebody who
/// published a post could see it in Home and had no way to remove it without
/// first opening it. Founder-observed 2026-08-29, sharing a photograph.
///
/// The fix is NOT a second delete. A confirmation, an endpoint and a set of
/// caches to invalidate are exactly the kind of thing that drifts once it
/// exists twice: one copy learns about a new cache and the other does not, and
/// the surface that forgot keeps showing deleted work. This file is the single
/// authority both cards call.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/navigation/canonical_destinations.dart';
import '../../../../../core/net/dio_provider.dart';
import '../../../../../core/ui/aura_platform_components.dart';
import '../../../../feed/data/unified_feed_providers.dart';
import '../../post_detail_screen.dart' show postProvider, repliesProvider;

/// Confirm, delete, and put every surface that cached the post back in step.
///
/// [parentPostId] is the post this one replies to, when it is a reply: the
/// parent's reply list caches it too, so a reply deleted from a thread has to
/// invalidate there as well or it lingers in the thread it was removed from.
///
/// [leaveSurfaceOnSuccess] distinguishes the two callers honestly. On a detail
/// screen the deleted post WAS the page, so staying would leave the person
/// looking at something that no longer exists. In a feed the post was one row
/// among many: the list refreshes and the person stays where they were.
Future<void> confirmAndDeletePost(
  BuildContext context,
  WidgetRef ref, {
  required String postId,
  String? parentPostId,
  bool leaveSurfaceOnSuccess = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Delete work'),
        content: const Text(
          'This will remove the work from the record. This action cannot be '
          'undone.',
        ),
        actions: [
          AuraGhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AuraPrimaryButton(
            label: 'Delete',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(dioProvider).delete('/posts/$postId');

    // Feed surfaces cache posts client-side (Riverpod) — without this, a
    // deleted post/reply keeps showing until the person manually refreshes.
    invalidateUnifiedFeedSurfaces(ref);
    ref.invalidate(postProvider(postId));
    final parent = (parentPostId ?? '').trim();
    if (parent.isNotEmpty) {
      ref.invalidate(repliesProvider(parent));
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Work deleted')));

    if (!leaveSurfaceOnSuccess) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go(memberHomeDestination());
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not delete post')));
  }
}

/// Open the editor for a post the viewer wrote.
void editOwnPost(BuildContext context, String postId) {
  final destination = postEditDestination(postId);
  if (destination == null) return;
  context.push(destination);
}
