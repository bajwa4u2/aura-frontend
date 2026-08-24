import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/conversation_unread_authority.dart';
import '../data/conversations_repository.dart';

/// ONE PLACE THAT KNOWS WHAT AN INBOX ACTION MEANS.
///
/// Founder ruling 2026-08-24: Messages must not own pin, archive, delete,
/// unread or leave semantics. It does not — the Conversation authority does —
/// but the CLIENT still needs one place that calls it, so a swipe, a
/// right-click, a long-press sheet and an overflow menu cannot drift into
/// three slightly different behaviours.
///
/// Every method here is a call plus the invalidation that follows it. No
/// widget performs an inbox mutation directly.
///
/// TWO LEDGERS ALWAYS REFRESH TOGETHER. The list and the Conversation unread
/// authority the drawer badge reads: refreshing one and not the other is how a
/// badge starts disagreeing with the list beneath it.
class ConversationActions {
  const ConversationActions(this._ref);

  final WidgetRef _ref;

  ConversationsRepository get _repo =>
      _ref.read(conversationsRepositoryProvider);

  void _refresh() {
    _ref.invalidate(conversationsListProvider);
    _ref.invalidate(conversationUnreadProvider);
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    String failure = 'That did not go through — try again.',
  }) async {
    try {
      await action();
      _refresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure)),
        );
      }
    }
  }

  Future<void> togglePin(BuildContext context, Conversation c) =>
      _run(context, () => _repo.setPinned(c.id, !c.pinned));

  Future<void> toggleArchive(BuildContext context, Conversation c) =>
      _run(context, () => _repo.setArchived(c.id, !c.archived));

  Future<void> toggleMute(BuildContext context, Conversation c) =>
      _run(context, () => _repo.setMuted(c.id, !c.muted));

  Future<void> markRead(BuildContext context, Conversation c) =>
      _run(context, () => _repo.markRead(c.id));

  Future<void> markUnread(BuildContext context, Conversation c) =>
      _run(context, () => _repo.markUnread(c.id));

  /// DELETE FROM MY HISTORY — confirmed, and worded as what it actually is.
  ///
  /// The confirmation says "your" deliberately and repeatedly. A person
  /// reading a dialog quickly must not come away believing they are erasing
  /// the other side of a correspondence, and they must not believe it is
  /// undoable either — an undoable delete is Archive, which is a different
  /// control sitting right beside this one.
  Future<void> deleteFromMyHistory(
    BuildContext context,
    Conversation c,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: const Text('Delete from your history?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This removes $title from YOUR conversation history. '
              'It does not delete anything for the people you were talking to '
              '— they keep their own copy.',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
            ),
            const SizedBox(height: AuraSpace.s12),
            Text(
              'You will still be a participant, so anything said from now on '
              'will appear. This cannot be undone — to hide a conversation '
              'reversibly, archive it instead.',
              style: AuraText.small.copyWith(color: AuraSurface.faint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete from my history'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(context, () => _repo.clearHistory(c.id));
  }

  /// LEAVE — participation, not history. Also confirmed, and the wording keeps
  /// the two apart: leaving does not delete what was said.
  Future<void> leave(
    BuildContext context,
    Conversation c,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: const Text('Leave this conversation?'),
        content: Text(
          'You will stop taking part in $title and stop receiving its '
          'messages. Your history is not deleted, and you can be brought '
          'back in later.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(context, () => _repo.leave(c.id));
  }
}

/// The full action set, reachable by long-press on touch and by right-click or
/// overflow on a pointer.
///
/// ONE SHEET FOR EVERY ENTRY POINT. Swipe covers the two reversible gestures;
/// everything else lives here, so no action is reachable only by a gesture
/// somebody might never discover — and no platform gets a different set.
Future<void> showConversationActionSheet(
  BuildContext context,
  WidgetRef ref,
  Conversation conversation,
  String title,
) {
  final actions = ConversationActions(ref);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AuraSurface.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AuraRadius.r18),
      ),
    ),
    builder: (sheetContext) {
      Widget item({
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        bool destructive = false,
      }) {
        return ListTile(
          leading: Icon(
            icon,
            size: 20,
            color: destructive ? AuraSurface.dangerInk : AuraSurface.muted,
          ),
          title: Text(
            label,
            style: AuraText.body.copyWith(
              color: destructive ? AuraSurface.dangerInk : AuraSurface.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: () {
            Navigator.of(sheetContext).pop();
            onTap();
          },
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.title,
                    ),
                  ),
                ],
              ),
            ),
            item(
              icon: conversation.pinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              label: conversation.pinned ? 'Unpin' : 'Pin',
              onTap: () => actions.togglePin(context, conversation),
            ),
            if (conversation.needsAttention)
              item(
                icon: Icons.mark_email_read_outlined,
                label: 'Mark as read',
                onTap: () => actions.markRead(context, conversation),
              )
            else
              item(
                icon: Icons.mark_email_unread_outlined,
                label: 'Mark as unread',
                onTap: () => actions.markUnread(context, conversation),
              ),
            item(
              icon: conversation.muted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              label: conversation.muted ? 'Unmute' : 'Mute',
              onTap: () => actions.toggleMute(context, conversation),
            ),
            item(
              icon: conversation.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              label: conversation.archived ? 'Move to inbox' : 'Archive',
              onTap: () => actions.toggleArchive(context, conversation),
            ),
            const Divider(height: 1, color: AuraSurface.divider),
            // The two that cannot be undone from here, kept below a line so
            // they are not adjacent to the reversible ones.
            item(
              icon: Icons.logout_rounded,
              label: 'Leave conversation',
              onTap: () => actions.leave(context, conversation, title),
            ),
            item(
              icon: Icons.delete_outline_rounded,
              label: 'Delete from my history',
              destructive: true,
              onTap: () =>
                  actions.deleteFromMyHistory(context, conversation, title),
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
        ),
      );
    },
  );
}
