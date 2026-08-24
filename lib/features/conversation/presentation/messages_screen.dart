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
import 'conversation_row.dart';
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
                // PINNED FORMS A STABLE PRIORITY REGION.
                //
                // Personal priority, so it is a region rather than a re-sort:
                // recency stays truthful INSIDE it, and the rest of the inbox
                // keeps its own order. Pinning does not rewrite chronology, it
                // decides which chronology you read first.
                final pinned =
                    conversations.where((c) => c.pinned).toList();
                final rest =
                    conversations.where((c) => !c.pinned).toList();

                // Swipe is a touch idiom. A pointer gets right-click, hover
                // and the overflow button instead — the same actions, reached
                // the way that platform reaches things.
                final allowSwipe = _isTouchPlatform(context);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pinned.isNotEmpty) ...[
                      const _RegionLabel('Pinned'),
                      for (final c in pinned)
                        ConversationRow(
                          conversation: c,
                          myUserId: myUserId,
                          allowSwipe: allowSwipe,
                        ),
                      if (rest.isNotEmpty) const _RegionLabel('Conversations'),
                    ],
                    for (final c in rest)
                      ConversationRow(
                        conversation: c,
                        myUserId: myUserId,
                        allowSwipe: allowSwipe,
                      ),
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

/// A quiet divider between the pinned region and the rest. Small, lower
/// contrast than a heading: it separates two orders without announcing itself
/// as a section of the product.
class _RegionLabel extends StatelessWidget {
  const _RegionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AuraSpace.s12,
        top: AuraSpace.s10,
        bottom: AuraSpace.s4,
      ),
      child: Text(
        label.toUpperCase(),
        style: AuraText.micro.copyWith(
          color: AuraSurface.faint,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Whether this platform's people swipe.
///
/// Asked of the PLATFORM, not the window size: a narrow desktop window is
/// still a pointer, and a wide tablet is still touch. Getting this from width
/// is how a desktop user ends up with a gesture they cannot perform and a
/// tablet user loses one they expect.
bool _isTouchPlatform(BuildContext context) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return true;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return false;
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
