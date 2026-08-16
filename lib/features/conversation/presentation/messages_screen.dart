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
      leading: AuraAvatar(name: name, size: 44),
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
      trailing: hasUnread
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            )
          : null,
      onTap: () =>
          context.push(NavigationAuthority.conversationRoute(conversation.id)),
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
