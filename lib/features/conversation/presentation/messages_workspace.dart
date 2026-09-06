import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_window.dart';
import 'conversation_screen.dart';
import 'messages_screen.dart';

/// MESSAGES, COMPOSED FOR THE WINDOW IT IS IN.
///
/// ── WHAT THIS REPLACES ──────────────────────────────────────────────────────
///
/// `/messages` rendered the list; `/messages/c/<id>` rendered the thread AND
/// NOTHING ELSE. On a 2011 px Windows window that meant a single 1068 px
/// column that swapped between the two, with a "← Back" button — a phone flow
/// on a desktop that has no back gesture, no back button, and room for both
/// things at once. Switching conversations meant going back to a list that had
/// been thrown away and rebuilt.
///
/// ── THE COMPOSITION ─────────────────────────────────────────────────────────
///
///   CONVERSATION SELECTION  |  ACTIVE CONVERSATION
///
/// The list is an OBJECT SELECTION region — the thing you are choosing
/// between — not a second navigation taxonomy. It carries no destinations,
/// only conversations, and it is present exactly when a person is choosing
/// among them.
///
/// Below the width where both can be themselves, this falls back to precisely
/// the previous behaviour: one at a time, with Back. That is not a compromise.
/// A 900 px window split two ways gives a conversation 500 px, which is worse
/// than either thing done properly.
///
/// ── WHY THE ROUTE STILL OWNS THE SELECTION ──────────────────────────────────
///
/// The selected conversation is the URL, exactly as before. Nothing here holds
/// selection state of its own, so a deep link, a notification tap, a refresh
/// and a click in the list all arrive the same way, and Back still means what
/// it meant. The pane composition is a rendering decision layered over the
/// route — never a second source of truth about which conversation is open.
class MessagesWorkspace extends ConsumerWidget {
  const MessagesWorkspace({super.key, this.conversationId});

  /// The conversation the route names. Null on `/messages` itself.
  final String? conversationId;

  /// The selection column's width.
  ///
  /// Wide enough for a name, a preview line and a timestamp without
  /// ellipsising all three, narrow enough that the conversation keeps the
  /// larger share — which is the point of the whole composition.
  static const double _selectionWidth = 340;

  /// Below this, the two panes stop being two things and become two cramped
  /// ones. Measured against the selection column plus a conversation that can
  /// still hold a readable message bubble.
  static const double splitFloor = 1040;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final win = AuraWindow.of(context);
    final canSplit =
        win.windowClass.canHoldSelection && win.workWidth >= splitFloor;

    if (!canSplit) {
      // The narrow composition, unchanged: whichever one the route names.
      return conversationId == null
          ? const MessagesScreen()
          : ConversationScreen(conversationId: conversationId!);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _selectionWidth,
          child: MessagesScreen(
            selectedConversationId: conversationId,
            // In the split the list is a column inside a larger surface, not
            // the surface itself: it keeps its own scroll and drops the page
            // padding that assumed it owned the width.
            embedded: true,
          ),
        ),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: AuraSurface.divider,
        ),
        Expanded(
          child: conversationId == null
              ? const _NoConversationSelected()
              : ConversationScreen(
                  // Keyed by the conversation so switching rebuilds the
                  // thread rather than mutating one in place -- scroll
                  // position, composer draft and read-marking all belong to
                  // the conversation, not to the pane.
                  //
                  // The Back control above it is suppressed by ReturnPathFrame
                  // for this route at this width: the list it would return to
                  // is on screen.
                  key: ValueKey(conversationId),
                  conversationId: conversationId!,
                ),
        ),
      ],
    );
  }
}

/// The resting state of the right pane.
///
/// Deliberately quiet and deliberately NOT an illustration or a call to
/// action: this is what a person sees for the half-second between opening
/// Messages and choosing something, and every time they leave a conversation.
/// It should read as "ready", not as an empty-state advertisement.
class _NoConversationSelected extends StatelessWidget {
  const _NoConversationSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 34,
              color: AuraSurface.faint.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AuraSpace.s12),
            Text(
              'Choose a conversation',
              style: AuraText.subtitle.copyWith(color: AuraSurface.muted),
            ),
          ],
        ),
      ),
    );
  }
}
