import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/compliance/blocks_repository.dart';
import '../../../../core/compliance/report_content_sheet.dart';
import '../../../../core/compliance/report_repository.dart';
import '../../../../core/ui/adaptive_dialog_action.dart';
import '../../../../core/ui/aura_notice.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../domain/realtime_models.dart';

/// LIVE AUDIENCE SAFETY (founder-approved design, 22 Oct 2026).
///
/// A public live is user content anyone on Aura can watch, so it carries the
/// same reporting path as every post (store guideline 1.2): the live itself
/// can be reported, and every speaker can be reported or blocked. One menu
/// for both entry points, built on the existing report sheet.
Future<void> showLiveSafetyMenu(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  RealtimeParticipant? speaker,
}) async {
  final name = _speakerName(speaker);
  final action = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AuraSurface.page,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (speaker == null)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report this live'),
              onTap: () => Navigator.of(ctx).pop('report-live'),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text('Report $name'),
              onTap: () => Navigator.of(ctx).pop('report-person'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text('Block $name'),
              onTap: () => Navigator.of(ctx).pop('block'),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case 'report-live':
      await ReportContentSheet.show(
        context,
        targetType: ReportTargetType.liveSession,
        targetId: sessionId,
        contextLabel: 'this live',
      );
      return;
    case 'report-person':
      await ReportContentSheet.show(
        context,
        targetType: ReportTargetType.user,
        targetId: speaker!.userId,
        contextLabel: name,
      );
      return;
    case 'block':
      // The block confirmation is the existing one, word for word.
      final ok = await showAdaptiveDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog.adaptive(
          title: const Text('Block this person?'),
          content: const Text(
            'You will stop seeing their posts and replies, and they cannot '
            'message you. You can unblock them later in Settings.',
          ),
          actions: [
            adaptiveDialogAction(
              dctx,
              label: 'Cancel',
              onPressed: () => Navigator.of(dctx).pop(false),
            ),
            adaptiveDialogAction(
              dctx,
              label: 'Block',
              destructive: true,
              onPressed: () => Navigator.of(dctx).pop(true),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      try {
        await blockUser(ref, speaker!.userId);
        if (!context.mounted) return;
        AuraNotice.done(context, 'Blocked.');
      } catch (_) {
        if (!context.mounted) return;
        AuraNotice.problem(context, 'This person was not blocked. Try again.');
      }
      return;
  }
}

String _speakerName(RealtimeParticipant? p) {
  if (p == null) return '';
  final name = p.displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final handle = p.handle?.trim() ?? '';
  if (handle.isNotEmpty) return '@$handle';
  return 'this person';
}
