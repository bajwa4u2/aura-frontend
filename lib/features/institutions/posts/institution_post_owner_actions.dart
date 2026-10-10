import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_mapper.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../data/institutions_repository.dart';

/// Whether [identity] may edit and delete posts of [institutionId]: an
/// operator of THAT institution who may speak for it. The backend re-checks
/// on every write. One rule for the post page and the feed card, so the two
/// cannot disagree about who governs a post.
bool governsInstitutionPosts(InstitutionIdentity? identity, String institutionId) {
  final id = institutionId.trim();
  return identity != null &&
      id.isNotEmpty &&
      identity.id == id &&
      identity.canPublishPosts;
}

/// The editor for an institution post.
String institutionPostEditPath(String institutionId, String postId) =>
    '/institution/$institutionId/posts/$postId/edit';

/// Confirm, then delete an institution post and clear it from every feed.
///
/// [leaveSurfaceOnSuccess]: on the post's own page the deleted post WAS the
/// page, so the person is taken back; in a feed it was one row among many and
/// the person stays where they were. Returns whether the post was deleted.
Future<bool> confirmAndDeleteInstitutionPost(
  BuildContext context,
  WidgetRef ref, {
  required String institutionId,
  required String postId,
  bool leaveSurfaceOnSuccess = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AuraSurface.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.card),
      ),
      title: const Text('Delete this post', style: AuraText.subtitle),
      content: Text(
        'This removes the post from every feed and its public link. '
        'This cannot be undone.',
        style: AuraText.body.copyWith(color: AuraSurface.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'Cancel',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'Delete',
            style: AuraText.small.copyWith(
              color: AuraSurface.coRose,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await ref
        .read(institutionsRepositoryProvider)
        .deleteInstitutionPost(institutionId, postId);
    // Remove the post from every feed surface so no orphaned card remains.
    invalidateUnifiedFeedSurfaces(ref);
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Post removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (leaveSurfaceOnSuccess && context.canPop()) context.pop();
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.from(e, feature: 'delete this post').message,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}
