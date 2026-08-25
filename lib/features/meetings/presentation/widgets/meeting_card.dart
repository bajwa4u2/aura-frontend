import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../domain/meeting.dart';
import '../../../../core/product/temporal.dart';
import '../../domain/meeting_lifecycle.dart';
import '../meeting_semantics.dart';
import 'meeting_surfaces.dart';

/// A MEETING, AS AN OBJECT RATHER THAN A ROW OF FIELDS.
///
/// Founder ruling 2026-08-25 §7. The card this replaces was a title, then a
/// status pill, then a relationship pill, then an institution pill, then a
/// line reading `"$timeLabel · $hostName"`, then the action label as TEXT, and
/// then the same action label again as a button. Seven stacked fragments, two
/// of them identical, and a person still had to read all of it to learn when
/// the meeting was.
///
/// §7 asks the card to answer four questions in seconds:
///
///   WHAT IS THIS?   the title, largest thing on the card
///   WHEN IS IT?     a calendar block, read at a glance, not parsed from prose
///   WHO / CONTEXT?  the host, and the institution when one convenes it
///   WHAT DO I DO?   exactly one action, on the right, where the eye ends
///
/// The date block is the change that does most of the work. A column of cards
/// each opening with DAY / NUMBER / MONTH can be scanned vertically for "when"
/// without reading a word of any of them, which is how a person actually uses
/// a list of meetings.
class MeetingCard extends StatelessWidget {
  const MeetingCard({
    super.key,
    required this.meeting,
    required this.relationship,
    required this.onOpen,
    this.onPrimaryAction,
    this.primaryActionLabel,
    this.dense = false,
  });

  final Meeting meeting;

  /// How this person stands to the meeting — "Organizer", "Invited", "Booked".
  /// Shown only when it is not obvious, see [_showsRelationship].
  final String relationship;

  final VoidCallback onOpen;

  /// The one thing worth doing from a list. Null when the only sensible act is
  /// to open the meeting, which the whole card already does.
  final VoidCallback? onPrimaryAction;
  final String? primaryActionLabel;

  /// Phone layout: the action moves under the content rather than beside it.
  final bool dense;

  MeetingPhase get _phase => meeting.phase;

  bool get _showsRelationship =>
      relationship.trim().isNotEmpty && relationship != 'Participant';

  (String, MeetingChipTone, IconData?) get _status => switch (_phase) {
        MeetingPhase.active => ('Live now', MeetingChipTone.live, Icons.circle),
        MeetingPhase.ready => ('Ready to join', MeetingChipTone.soon, null),
        MeetingPhase.scheduled => ('Scheduled', MeetingChipTone.neutral, null),
        MeetingPhase.ended => ('Ended', MeetingChipTone.neutral, null),
        MeetingPhase.cancelled => ('Cancelled', MeetingChipTone.neutral, null),
        MeetingPhase.missed => ('Missed', MeetingChipTone.neutral, null),
        MeetingPhase.draft => ('Draft', MeetingChipTone.neutral, null),
        MeetingPhase.unknown => ('Status unavailable', MeetingChipTone.neutral, null),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, tone, statusIcon) = _status;
    final institution = meeting.owningInstitution?.name ?? '';
    final host = meeting.host?.name ?? '';
    final at = meeting.scheduledAt;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MeetingTag(
              label: statusLabel,
              tone: tone,
              icon: statusIcon,
            ),
            if (_showsRelationship) ...[
              const SizedBox(width: AuraSpace.s8),
              Text(
                relationship,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AuraSurface.muted),
              ),
            ],
          ],
        ),
        const SizedBox(height: AuraSpace.s10),
        Text(
          meeting.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AuraSpace.s6),
        // One line, not three pills. Time first because it is what a person
        // is looking for once they know which meeting this is.
        Text(
          [
            if (at != null) _clock(at),
            '${meeting.durationMinutes} min',
            if (host.isNotEmpty) host,
            if (institution.isNotEmpty) institution,
          ].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: AuraSurface.muted),
        ),
      ],
    );

    final action = onPrimaryAction == null
        ? null
        : MeetingAction(
            label: '${primaryActionLabel ?? 'Open'} — ${meeting.title}',
            child: _phase == MeetingPhase.active || _phase == MeetingPhase.ready
                ? FilledButton(
                    onPressed: onPrimaryAction,
                    child: Text(primaryActionLabel ?? 'Join'),
                  )
                : OutlinedButton(
                    onPressed: onPrimaryAction,
                    child: Text(primaryActionLabel ?? 'Open'),
                  ),
          );

    return Semantics(
      button: true,
      label: MeetingSemantics.meeting(
        title: meeting.title,
        phase: _phase,
        scheduledAt: at,
        hostName: host.isEmpty ? null : host,
        institutionName: institution.isEmpty ? null : institution,
      ),
      excludeSemantics: true,
      child: AuraCard(
        onTap: onOpen,
        padding: const EdgeInsets.all(AuraSpace.s14),
        child: dense
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateBlock(at: at, phase: _phase),
                      const SizedBox(width: AuraSpace.s14),
                      Expanded(child: content),
                    ],
                  ),
                  if (action != null) ...[
                    const SizedBox(height: AuraSpace.s12),
                    SizedBox(width: double.infinity, child: action),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _DateBlock(at: at, phase: _phase),
                  const SizedBox(width: AuraSpace.s16),
                  Expanded(child: content),
                  if (action != null) ...[
                    const SizedBox(width: AuraSpace.s14),
                    action,
                  ],
                ],
              ),
      ),
    );
  }

  static String _clock(DateTime at) {
    // C0 ratchet: one governed place applies the local zone.
    final local = ProductTime(at, TimeEvent.scheduled).local;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// THE CALENDAR BLOCK.
///
/// Fixed width on purpose: a column of these lines up, so the eye can run
/// down the dates without the text beside them shifting it around.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.at, required this.phase});

  final DateTime? at;
  final MeetingPhase phase;

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = phase == MeetingPhase.active;
    final over = phase == MeetingPhase.ended ||
        phase == MeetingPhase.cancelled ||
        phase == MeetingPhase.missed;

    final local =
        at == null ? null : ProductTime(at!, TimeEvent.scheduled).local;
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s10),
      decoration: BoxDecoration(
        color: live ? AuraSurface.accentSoft : AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        border: live
            ? Border.all(color: AuraSurface.accent.withValues(alpha: 0.45))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: local == null
            ? [
                // An instant meeting has no date to show, and inventing one
                // would be worse than saying so.
                Icon(Icons.bolt_rounded,
                    size: 20,
                    color: live ? AuraSurface.accentText : AuraSurface.muted),
                const SizedBox(height: 2),
                Text('NOW',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: live ? AuraSurface.accentText : AuraSurface.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    )),
              ]
            : [
                Text(
                  _days[(local.weekday - 1).clamp(0, 6)],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: live ? AuraSurface.accentText : AuraSurface.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${local.day}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: over ? AuraSurface.muted : AuraSurface.ink,
                  ),
                ),
                Text(
                  _months[(local.month - 1).clamp(0, 11)],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: live ? AuraSurface.accentText : AuraSurface.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
      ),
    );
  }
}
