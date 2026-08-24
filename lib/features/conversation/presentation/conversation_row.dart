import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/navigation_authority.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/conversations_repository.dart';
import 'conversation_avatar.dart';
import 'conversation_identity.dart';
import 'conversation_row_actions.dart';

/// ONE CONVERSATION, AS THE INBOX SHOWS IT.
///
/// Founder ruling 2026-08-24, §16–§18. Communication-first, not a dashboard
/// and not a wall of controls: identity leads, continuity and recency sit under
/// it, and state shows only where it is true.
///
/// THE HIERARCHY IS DELIBERATE. Identity is the largest thing, because that is
/// what someone scans for. Continuity — the newest thing said — is the second
/// line, because that is what tells them whether to open it. Recency and
/// attention are the right edge, quiet unless there is something owed. Pin and
/// mute are small marks rather than labels, because they are states, not
/// announcements.
///
/// EVERY GESTURE REACHES THE SAME AUTHORITY. Right swipe pins, left swipe
/// archives — the two reversible actions, so an accidental gesture is never
/// costly. Delete is deliberately NOT a swipe: it lives in the sheet behind a
/// confirmation. Long-press on touch and right-click on a pointer open the
/// same sheet, and an overflow button makes it discoverable without either.
class ConversationRow extends ConsumerWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.myUserId,
    required this.allowSwipe,
  });

  final Conversation conversation;
  final String myUserId;

  /// Swipe is a touch idiom. On a pointer it would be an emulation of a
  /// gesture nobody performs, so the pointer gets hover and right-click
  /// instead — the same actions, reached the way that platform reaches things.
  final bool allowSwipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = _Body(conversation: conversation, myUserId: myUserId);
    if (!allowSwipe) return row;

    final actions = ConversationActions(ref);

    return Dismissible(
      key: ValueKey('conv-${conversation.id}'),
      // Neither direction destroys anything, so neither confirms. Both are one
      // tap from being undone by the same gesture.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await actions.togglePin(context, conversation);
        } else {
          await actions.toggleArchive(context, conversation);
        }
        // Never actually dismiss: the row stays and its state changes. A row
        // that vanished would look like deletion, which is precisely the
        // conflation this reconstruction exists to end.
        return false;
      },
      // A deliberate threshold: far enough that a scroll is not mistaken for
      // an action.
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.28,
        DismissDirection.endToStart: 0.28,
      },
      background: _SwipeAffordance(
        alignment: Alignment.centerLeft,
        icon: conversation.pinned
            ? Icons.push_pin_outlined
            : Icons.push_pin_rounded,
        label: conversation.pinned ? 'Unpin' : 'Pin',
      ),
      secondaryBackground: _SwipeAffordance(
        alignment: Alignment.centerRight,
        icon: conversation.archived
            ? Icons.unarchive_outlined
            : Icons.archive_outlined,
        label: conversation.archived ? 'Inbox' : 'Archive',
      ),
      child: row,
    );
  }
}

class _SwipeAffordance extends StatelessWidget {
  const _SwipeAffordance({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AuraSurface.accentText),
          const SizedBox(width: AuraSpace.s6),
          Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.accentText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.conversation, required this.myUserId});

  final Conversation conversation;
  final String myUserId;

  /// What the newest message says, when it can be shown — and what it WAS,
  /// when it cannot.
  ///
  /// A retraction previews as a withdrawal and an attachment describes itself.
  /// Rendering an empty line for either would make a live conversation look
  /// broken.
  String? _continuity() {
    final latest = conversation.latest;
    if (latest == null) return null;

    final mine = latest.senderUserId == myUserId;
    final who = mine ? 'You: ' : '';

    if (latest.retracted) return '${mine ? 'You ' : ''}withdrew a message';

    if (!latest.isText || latest.preview.isEmpty) {
      final what = switch (latest.contentKind) {
        'IMAGE' => 'a photo',
        'VIDEO' => 'a video',
        'AUDIO' => 'a voice message',
        'FILE' => 'a file',
        _ => 'a message',
      };
      return '$who${mine ? 'sent' : 'Sent'} $what';
    }
    return '$who${latest.preview}';
  }

  /// The provenance line: what KIND of conversation this is, when that is not
  /// obvious from the name. Silent for an ordinary person-to-person thread,
  /// because saying "conversation" there is noise.
  String? _context() {
    final institutional =
        conversation.parties.any((p) => !p.isPerson && p.isActive);
    if (institutional) return 'Institution';
    if (!conversation.isDirect && conversation.parties.length > 2) {
      return '${conversation.parties.length} people';
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = conversationDisplayName(conversation, myUserId);
    final attention = conversation.needsAttention;
    final continuity = _continuity();
    final contextLabel = _context();

    void openSheet() => showConversationActionSheet(
          context,
          ref,
          conversation,
          name,
        );

    return InkWell(
      onTap: () =>
          context.push(NavigationAuthority.conversationRoute(conversation.id)),
      // Touch and pointer reach the same sheet. Neither platform gets a
      // different set of actions.
      onLongPress: openSheet,
      onSecondaryTap: openSheet,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s12,
        ),
        decoration: BoxDecoration(
          // Attention gets a surface, not a shout. A conversation with
          // something owed sits slightly forward of the rest.
          color: attention ? AuraSurface.card : Colors.transparent,
          borderRadius: BorderRadius.circular(AuraRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConversationAvatar(
              conversation: conversation,
              myUserId: myUserId,
              size: 46,
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.body.copyWith(
                            fontWeight:
                                attention ? FontWeight.w800 : FontWeight.w600,
                            color: AuraSurface.ink,
                          ),
                        ),
                      ),
                      if (conversation.pinned) ...[
                        const SizedBox(width: AuraSpace.s6),
                        const Icon(Icons.push_pin_rounded,
                            size: 12, color: AuraSurface.faint),
                      ],
                      if (conversation.muted) ...[
                        const SizedBox(width: AuraSpace.s4),
                        const Icon(Icons.notifications_off_outlined,
                            size: 12, color: AuraSurface.faint),
                      ],
                    ],
                  ),
                  if (continuity != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      continuity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small.copyWith(
                        color: attention
                            ? AuraSurface.ink
                            : AuraSurface.muted,
                        fontStyle: conversation.latest?.retracted == true
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                  if (contextLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      contextLabel,
                      style:
                          AuraText.micro.copyWith(color: AuraSurface.faint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conversation.lastMessageAt != null)
                  Text(
                    // The one temporal authority every surface reads.
                    AuraTemporal.humanize(
                      ProductTime(conversation.lastMessageAt!, TimeEvent.sent),
                      style: TemporalStyle.compact,
                    ),
                    style: AuraText.micro.copyWith(
                      color: attention ? AuraSurface.ink : AuraSurface.faint,
                      fontWeight:
                          attention ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: AuraSpace.s6),
                _AttentionMark(conversation: conversation),
              ],
            ),
            // Discoverable without a gesture, on every platform.
            _OverflowButton(onTap: openSheet),
          ],
        ),
      ),
    );
  }
}

/// Attention, shown as what it is.
///
/// A count when messages are genuinely unread; a plain dot when the person
/// asserted unread themselves, because there is no number to state and
/// inventing "1" would be a small lie.
class _AttentionMark extends StatelessWidget {
  const _AttentionMark({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    if (conversation.unreadCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AuraSurface.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
          style: AuraText.micro
              .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );
    }
    if (conversation.manuallyUnread) {
      return Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          color: AuraSurface.accent,
          shape: BoxShape.circle,
        ),
      );
    }
    return const SizedBox(width: 9, height: 9);
  }
}

class _OverflowButton extends StatelessWidget {
  const _OverflowButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Conversation options',
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.more_horiz_rounded,
          size: 18, color: AuraSurface.faint),
    );
  }
}
