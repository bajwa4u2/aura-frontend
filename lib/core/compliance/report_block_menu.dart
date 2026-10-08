import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/aura_surface.dart';
import 'blocks_repository.dart';
import 'report_content_sheet.dart';
import 'report_repository.dart';

/// REPORT AND BLOCK, WHEREVER SOMEONE ELSE'S CONTENT IS MET.
///
/// App Store Guideline 1.2 and Google Play's user-generated-content policy
/// require a way to report objectionable content and to block abusive users
/// on the surfaces where people actually meet that content. The main feed card
/// and the top of a discussion had neither (child-safety audit, 2026-10-08);
/// only older surfaces did. One menu, used everywhere, so the surfaces cannot
/// drift on what reporting or blocking means.
///
/// [blockUserId] is the person behind the content when there is one. An
/// institution's post or an announcement has no single person to block, so
/// only Report is offered there.
Future<void> showReportBlockMenu(
  BuildContext context,
  WidgetRef ref, {
  required ReportTargetType targetType,
  required String targetId,
  required String contextLabel,
  String? blockUserId,
}) async {
  final blockId = (blockUserId ?? '').trim();
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AuraSurface.page,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text('Report $contextLabel'),
            subtitle: const Text('A moderator reviews reports within 24 hours.'),
            onTap: () => Navigator.of(ctx).pop('report'),
          ),
          if (blockId.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block this person'),
              subtitle: const Text(
                'You will stop seeing their posts and replies, and they '
                'cannot message you.',
              ),
              onTap: () => Navigator.of(ctx).pop('block'),
            ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'report':
      await ReportContentSheet.show(
        context,
        targetType: targetType,
        targetId: targetId,
        contextLabel: contextLabel,
      );
      return;
    case 'block':
      final ok = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Block this person?'),
          content: const Text(
            'You will stop seeing their posts and replies, and they cannot '
            'message you. You can unblock them later in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      try {
        await blockUser(ref, blockId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blocked.')),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not block. Try again later.')),
        );
      }
      return;
  }
}
