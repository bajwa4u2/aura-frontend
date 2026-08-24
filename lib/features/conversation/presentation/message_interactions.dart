import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/conversations_repository.dart';

/// WHAT YOU CAN DO TO A MESSAGE, AND WHO MAY DO IT.
///
/// Founder ruling 2026-08-24, §10–§12 and §19. Every verb here calls the
/// Conversation authority; none of them decides anything. The client's job is
/// to offer the right verbs to the right person and to render the result
/// truthfully.
///
/// ELIGIBILITY IS ASKED, NOT ASSUMED. Edit and retract are the author's; the
/// author is the only one offered them. Remove-for-me is anyone's, including
/// for a message they wrote. A retracted message offers almost nothing,
/// because there is nothing left to act on. Getting this wrong produces
/// controls that fail — the founder's own finding about Follow, in a different
/// place.

/// The reaction vocabulary this surface offers.
///
/// Deliberately short. A long palette turns a reaction into a decision, and
/// the shared engagement authority accepts a `ReactionType` rather than
/// arbitrary emoji, so these are the ones that actually persist.
const List<({String type, String glyph, String label})> kMessageReactions = [
  (type: 'LIKE', glyph: '👍', label: 'Like'),
  (type: 'LOVE', glyph: '❤️', label: 'Love'),
  (type: 'LAUGH', glyph: '😄', label: 'Laugh'),
  (type: 'SAD', glyph: '😢', label: 'Sad'),
  (type: 'ANGRY', glyph: '😠', label: 'Angry'),
];

String reactionGlyph(String type) {
  for (final r in kMessageReactions) {
    if (r.type == type) return r.glyph;
  }
  // An unknown type still renders as something rather than vanishing: the
  // server's vocabulary may legitimately grow before this list does.
  return '•';
}

/// The one place that performs message mutations.
///
/// Mirrors ConversationActions on the inbox side, for the same reason: a long
/// press, a right-click and a hover control must not drift into three
/// slightly different behaviours.
class MessageActions {
  const MessageActions(this._ref, this.conversationId);

  final WidgetRef _ref;
  final String conversationId;

  ConversationsRepository get _repo =>
      _ref.read(conversationsRepositoryProvider);

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String failure,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure)));
      }
    }
  }

  /// Toggle semantics live in the engagement authority: reacting with the same
  /// type again removes it, and a different type replaces it. The client does
  /// not reimplement that — it just says which way the tap went.
  Future<void> react(
    BuildContext context,
    ConversationMessage message,
    String type,
  ) async {
    final already = message.myReaction == type;
    await _run(
      context,
      () => already
          ? _repo.unreactMessage(conversationId, message.id)
          : _repo.reactToMessage(conversationId, message.id, type),
      'That reaction did not go through — try again.',
    );
  }

  Future<void> retract(
    BuildContext context,
    ConversationMessage message,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Retract this message?',
      body: 'It will be withdrawn for everyone in this conversation. They '
          'will see that a message was removed, and replies to it stay '
          'where they are.',
      confirm: 'Retract for everyone',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(
      context,
      () => _repo.retractMessage(conversationId, message.id),
      'That message could not be retracted — try again.',
    );
  }

  /// REMOVE FOR ME — deliberately worded so it cannot be mistaken for retract.
  /// The two sit next to each other in the sheet, and the difference is the
  /// whole point.
  Future<void> removeForMe(
    BuildContext context,
    ConversationMessage message,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Remove from your view?',
      body: 'This hides the message for you only. Everyone else keeps it, and '
          'the person who wrote it is not told.',
      confirm: 'Remove for me',
    );
    if (!confirmed) return;
    await _run(
      context,
      () => _repo.removeMessageForMe(conversationId, message.id),
      'That message could not be removed — try again.',
    );
  }

  Future<void> edit(
    BuildContext context,
    ConversationMessage message,
    String body,
  ) =>
      _run(
        context,
        () => _repo.editMessage(conversationId, message.id, body),
        'That edit did not save — try again.',
      );

  /// FORWARD — reports what actually travelled.
  ///
  /// Attachments can legitimately refuse: content still being examined must
  /// not move past the check holding it. Saying so is the difference between
  /// a governed transfer and a silent partial one.
  Future<void> forward(
    BuildContext context,
    ConversationMessage message,
    String destinationConversationId,
  ) async {
    try {
      final result = await _repo.forwardMessage(
        conversationId,
        message.id,
        destinationConversationId,
      );
      if (!context.mounted) return;
      final text = result.hadRefusals
          ? 'Forwarded. ${result.refusedReasons.length} attachment'
              '${result.refusedReasons.length == 1 ? '' : 's'} could not be '
              'sent yet.'
          : result.attachments > 0
              ? 'Forwarded with ${result.attachments} attachment'
                  '${result.attachments == 1 ? '' : 's'}.'
              : 'Forwarded.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text)));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That could not be forwarded.')),
        );
      }
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirm,
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: Text(title),
        content: Text(
          body,
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirm,
              style: destructive
                  ? const TextStyle(color: AuraSurface.dangerInk)
                  : null,
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }
}

/// Reactions on a message, as they were actually recorded.
///
/// Shows the types present and the total, with this viewer's own highlighted.
/// Tapping one toggles it — the same authority the sheet uses, so a tap here
/// and a tap there cannot disagree.
class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({
    super.key,
    required this.message,
    required this.onToggle,
  });

  final ConversationMessage message;
  final void Function(String type) onToggle;

  @override
  Widget build(BuildContext context) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();

    final entries = message.reactions.entries
        .where((e) => e.value > 0)
        .toList()
      // Stable order, so a reaction does not jump when a count changes.
      ..sort((a, b) => a.key.compareTo(b.key));

    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.s6),
      child: Wrap(
        spacing: AuraSpace.s4,
        runSpacing: AuraSpace.s4,
        children: [
          for (final e in entries)
            _Pill(
              glyph: reactionGlyph(e.key),
              count: e.value,
              mine: message.myReaction == e.key,
              onTap: () => onToggle(e.key),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.glyph,
    required this.count,
    required this.mine,
    required this.onTap,
  });

  final String glyph;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: mine ? AuraSurface.accentSoft : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: mine
                ? AuraSurface.accent.withValues(alpha: 0.45)
                : AuraSurface.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(glyph, style: const TextStyle(fontSize: 12)),
            if (count > 1) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: AuraText.micro.copyWith(
                  color: mine ? AuraSurface.ink : AuraSurface.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The full message action set.
///
/// Opened by long press on touch and right-click on a pointer — the same
/// sheet, so the two platforms cannot drift apart. The reaction row sits at
/// the top because it is the most common act and the least destructive; the
/// two removals sit at the bottom, below a divider, worded so they cannot be
/// confused with one another.
Future<void> showMessageActionSheet(
  BuildContext context, {
  required ConversationMessage message,
  required bool mine,
  required void Function(String action) onAction,
  required void Function(String reactionType) onReact,
}) {
  final retracted = message.deleted;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AuraSurface.card,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AuraRadius.r18)),
    ),
    builder: (sheetContext) {
      Widget item({
        required IconData icon,
        required String label,
        required String action,
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
            onAction(action);
          },
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A retracted message has nothing to react to — its content is
            // gone. Offering the row anyway would imply otherwise.
            if (!retracted)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s12,
                  AuraSpace.s14,
                  AuraSpace.s12,
                  AuraSpace.s6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final r in kMessageReactions)
                      IconButton(
                        tooltip: r.label,
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          onReact(r.type);
                        },
                        icon: Text(
                          r.glyph,
                          style: TextStyle(
                            fontSize: 22,
                            // The viewer's own reaction reads as already-set.
                            color: message.myReaction == r.type
                                ? AuraSurface.ink
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (!retracted) ...[
              const Divider(height: 1, color: AuraSurface.divider),
              item(
                icon: Icons.reply_rounded,
                label: 'Reply',
                action: 'reply',
              ),
              item(
                icon: Icons.forward_rounded,
                label: 'Forward',
                action: 'forward',
              ),
              if (mine)
                item(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  action: 'edit',
                ),
              item(
                icon: Icons.copy_rounded,
                label: 'Copy text',
                action: 'copy',
              ),
              item(
                icon: Icons.translate_rounded,
                label: 'Translate',
                action: 'translate',
              ),
              if (!mine)
                item(
                  icon: Icons.flag_outlined,
                  label: 'Report',
                  action: 'report',
                ),
              const Divider(height: 1, color: AuraSurface.divider),
            ],
            // THE TWO REMOVALS. Different consequences, so different words and
            // a line between them and everything else.
            if (mine && !retracted)
              item(
                icon: Icons.undo_rounded,
                label: 'Retract for everyone',
                action: 'retract',
                destructive: true,
              ),
            item(
              icon: Icons.visibility_off_outlined,
              label: 'Remove for me',
              action: 'removeForMe',
              destructive: true,
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
        ),
      );
    },
  );
}
