import '../data/conversation_unread_authority.dart';
import '../../../core/product/temporal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/navigation_authority.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/conversations_repository.dart';
import 'conversation_avatar.dart';
import 'conversation_identity.dart';

/// MESSAGES = where my Conversations live (canon).
/// One coherent list. No tabs, no second inbox, no architecture-derived
/// segmentation — archived is a filter, invitations render inline until
/// C4 assumes obligation projection.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = _showArchived
        ? ref.watch(_archivedConversationsProvider)
        : ref.watch(conversationsListProvider);
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    final myUserId = ref.watch(myUserIdProvider);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conversationsListProvider);
          ref.invalidate(_archivedConversationsProvider);
          ref.invalidate(pendingInvitationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            Row(
              children: [
                const Expanded(
                    child: Text('Messages', style: AuraText.display)),
                AuraPrimaryButton(
                  label: 'New conversation',
                  icon: Icons.add_comment_outlined,
                  onPressed: () =>
                      context.push(NavigationAuthority.newConversationRoute),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s12),
            Row(
              children: [
                FilterChip(
                  selected: _showArchived,
                  onSelected: (v) => setState(() => _showArchived = v),
                  label: const Text('Archived'),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s12),
            ...invitationsAsync.maybeWhen(
              data: (invitations) => [
                for (final inv in invitations
                    .where((i) => i.targetKind == 'CONVERSATION'))
                  _InvitationRow(invitation: inv),
              ],
              orElse: () => const <Widget>[],
            ),
            conversationsAsync.when(
              loading: () => const AuraProductState(
                state: ProductState.loading,
                subject: ProductNoun.conversation,
              ),
              error: (e, _) => AuraProductState(
                state: ProductState.retryableError,
                subject: ProductNoun.conversation,
                onRecover: () => ref.invalidate(conversationsListProvider),
              ),
              data: (conversations) {
                if (conversations.isEmpty) {
                  return AuraProductState(
                    state: ProductState.empty,
                    subject: ProductNoun.conversation,
                    headline: _showArchived
                        ? 'No archived conversations'
                        : 'Your conversations live here',
                    detail: _showArchived
                        ? 'Conversations you archive appear here.'
                        : 'Start a conversation — pick a person and talk.',
                    icon: Icons.forum_outlined,
                    action: _showArchived
                        ? null
                        : AuraPrimaryButton(
                            label: 'Start a conversation',
                            onPressed: () => context
                                .push(NavigationAuthority.newConversationRoute),
                          ),
                  );
                }
                return Column(
                  children: [
                    for (final c in conversations)
                      _ConversationRow(conversation: c, myUserId: myUserId),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final _archivedConversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  return ref.watch(conversationsRepositoryProvider).list(archived: true);
});

class _ConversationRow extends ConsumerWidget {
  const _ConversationRow({required this.conversation, required this.myUserId});
  final Conversation conversation;
  final String myUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = conversationDisplayName(conversation, myUserId);
    final hasUnread = conversation.unreadCount > 0;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AuraSpace.s8, vertical: 2),
      // F056: a conversation looks like its people — counterpart avatar for
      // 1:1, bounded composite for a group.
      leading: ConversationAvatar(
        conversation: conversation,
        myUserId: myUserId,
        size: 44,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AuraText.body.copyWith(
          fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
          color: AuraSurface.ink,
        ),
      ),
      subtitle: conversation.parties.any((p) => !p.isPerson && p.isActive)
          ? Text('Institution conversation',
              style: AuraText.micro.copyWith(color: AuraSurface.muted))
          : null,
      // THE ORDER IS TEMPORAL, SO THE READER MUST BE ABLE TO SEE TIME.
      // The list is sorted by `lastMessageAt` descending on the server and
      // that value reaches the client, but nothing rendered it — so a
      // correctly ordered list looked arbitrarily ordered, and there was no
      // way to tell a conversation from this morning from one from March.
      // Time comes from the canonical temporal authority, the same one every
      // other surface reads, rather than a formatter declared here.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (conversation.muted)
            const Padding(
              padding: EdgeInsets.only(right: AuraSpace.s6),
              child: Icon(Icons.notifications_off_outlined,
                  size: 16, color: AuraSurface.faint),
            ),
          if (conversation.lastMessageAt != null || hasUnread)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (conversation.lastMessageAt != null)
                  Text(
                    AuraTemporal.humanize(
                      ProductTime(conversation.lastMessageAt!, TimeEvent.sent),
                      style: TemporalStyle.compact,
                    ),
                    style: AuraText.micro.copyWith(
                      color:
                          hasUnread ? AuraSurface.ink : AuraSurface.faint,
                      fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AuraSurface.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      conversation.unreadCount > 99
                          ? '99+'
                          : '${conversation.unreadCount}',
                      style: AuraText.micro.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          _ConversationRowMenu(conversation: conversation),
        ],
      ),
      onTap: () =>
          context.push(NavigationAuthority.conversationRoute(conversation.id)),
    );
  }
}


/// THE CONTROLS A CONVERSATION LIST IS SUPPOSED TO HAVE.
///
/// Mute, archive, mark-as-read and leave all existed on the repository and
/// none of them were reachable from this list — the row had a tap target and
/// nothing else, so the only way to act on a conversation was to open it and
/// hunt. These are the actions the backend already governs; nothing new is
/// invented here, it is exposed where the person is when they want it.
///
/// LEAVING IS DIFFERENT FROM THE OTHERS. Mute and archive are reversible from
/// this same menu, so they act immediately. Leaving a conversation is not
/// something this surface can undo, so it asks first and says plainly what
/// will happen.
class _ConversationRowMenu extends ConsumerStatefulWidget {
  const _ConversationRowMenu({required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<_ConversationRowMenu> createState() =>
      _ConversationRowMenuState();
}

enum _RowAction { markRead, mute, archive, leave }

class _ConversationRowMenuState extends ConsumerState<_ConversationRowMenu> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      // Both ledgers refresh: the list itself, and the Conversation unread
      // authority the drawer badge reads. Refreshing one and not the other is
      // how a badge starts disagreeing with the list under it.
      ref.invalidate(conversationsListProvider);
      ref.invalidate(conversationUnreadProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That did not go through — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmLeave() async {
    final name = conversationDisplayName(
      widget.conversation,
      ref.read(myUserIdProvider) ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: const Text('Leave this conversation?'),
        content: Text(
          'You will stop receiving messages in $name, and it will no longer '
          'appear in your list.',
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
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    final repo = ref.read(conversationsRepositoryProvider);

    return PopupMenuButton<_RowAction>(
      enabled: !_busy,
      tooltip: 'Conversation options',
      icon: const Icon(Icons.more_horiz_rounded,
          size: 20, color: AuraSurface.faint),
      color: AuraSurface.card,
      itemBuilder: (context) => [
        if (c.unreadCount > 0)
          const PopupMenuItem(
            value: _RowAction.markRead,
            child: Text('Mark as read'),
          ),
        PopupMenuItem(
          value: _RowAction.mute,
          child: Text(c.muted ? 'Unmute' : 'Mute'),
        ),
        PopupMenuItem(
          value: _RowAction.archive,
          child: Text(c.archived ? 'Move to inbox' : 'Archive'),
        ),
        const PopupMenuItem(
          value: _RowAction.leave,
          child: Text('Leave conversation'),
        ),
      ],
      onSelected: (action) async {
        switch (action) {
          case _RowAction.markRead:
            await _run(() => repo.markRead(c.id));
          case _RowAction.mute:
            await _run(() => repo.setMuted(c.id, !c.muted));
          case _RowAction.archive:
            await _run(() => repo.setArchived(c.id, !c.archived));
          case _RowAction.leave:
            if (await _confirmLeave()) await _run(() => repo.leave(c.id));
        }
      },
    );
  }
}

class _InvitationRow extends ConsumerWidget {
  const _InvitationRow({required this.invitation});
  final PendingInvitation invitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s8),
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline_rounded,
              size: 18, color: AuraSurface.accentText),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              'You were invited to a conversation'
              '${(invitation.note ?? '').isNotEmpty ? ' — "${invitation.note}"' : ''}',
              style: AuraText.small.copyWith(color: AuraSurface.ink),
            ),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(conversationsRepositoryProvider);
              await repo.declineInvitation(invitation.id);
              ref.invalidate(pendingInvitationsProvider);
            },
            child: const Text('Decline'),
          ),
          AuraPrimaryButton(
            label: 'Accept',
            onPressed: () async {
              final repo = ref.read(conversationsRepositoryProvider);
              await repo.acceptInvitation(invitation.id);
              ref.invalidate(pendingInvitationsProvider);
              ref.invalidate(conversationsListProvider);
              if (context.mounted) {
                context.push(
                    NavigationAuthority.conversationRoute(invitation.targetId));
              }
            },
          ),
        ],
      ),
    );
  }
}
