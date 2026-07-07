import 'package:flutter/material.dart';

import '../../../../core/ui/aura_space.dart';
import '../../domain/meeting.dart';

/// First-class Meeting PREPARATION surface — the shared brief shown before
/// joining, on BOTH the guest pre-join and the host lobby. One system, not two
/// stitched screens.
///
/// Shows: institution + host identity, title, schedule, about, agenda /
/// preparation notes, participants, and a materials (attachments) section.
/// The agenda text here is PREPARATION material — distinct from live meeting
/// notes (the live notes/summary bridge lands in Phase 2).
class MeetingPreparationPanel extends StatelessWidget {
  const MeetingPreparationPanel({
    super.key,
    required this.meeting,
    this.dense = false,
  });

  final Meeting meeting;

  /// Tighter spacing for the host lobby where vertical space is shared with the
  /// room controls.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final institution = meeting.booking?.institution;
    final host = meeting.host;
    final gap = dense ? AuraSpace.s12 : AuraSpace.s16;

    final agendaLines = (meeting.preparationNotes ?? '')
        .trim()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final participants = meeting.participants
        .where((p) => p.displayName.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Identity — organisation first, host second.
        _card(
          context,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (institution != null)
                _Avatar(
                  name: institution.name,
                  logoUrl: institution.logoUrl,
                  icon: Icons.business_rounded,
                ),
              if (institution != null && host != null)
                const SizedBox(width: AuraSpace.s10),
              if (host != null)
                _Avatar(
                  name: host.name,
                  logoUrl: host.avatarUrl,
                  icon: Icons.person_outline_rounded,
                ),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      institution?.name ?? host?.name ?? meeting.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // Identity dedupe: when there is no institution the card
                      // title IS the host's name — repeating "Hosted by <same
                      // name>" underneath reads broken. Show their role line
                      // instead, or the hosting line only when it adds info.
                      host == null
                          ? 'Host details unavailable'
                          : (host.title?.trim().isNotEmpty == true
                              ? host.title!.trim()
                              : (institution != null
                                  ? 'Hosted by ${host.name}'
                                  : 'Meeting host')),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),

        // Title + schedule.
        Text(
          meeting.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        _MetaRow(
          icon: Icons.schedule_rounded,
          text: _scheduleLabel(context),
        ),
        _MetaRow(icon: Icons.public_rounded, text: meeting.timezone),
        _MetaRow(
          icon: Icons.timelapse_rounded,
          text: '${meeting.durationMinutes} min',
        ),

        // About.
        if ((meeting.description ?? '').trim().isNotEmpty) ...[
          SizedBox(height: gap),
          const _SectionLabel('About this meeting'),
          const SizedBox(height: AuraSpace.s6),
          Text(
            meeting.description!.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFCBD5E1),
              height: 1.45,
            ),
          ),
        ],

        // Agenda / preparation notes.
        if (agendaLines.isNotEmpty) ...[
          SizedBox(height: gap),
          const _SectionLabel('Agenda & preparation'),
          const SizedBox(height: AuraSpace.s8),
          ...agendaLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('· ', style: TextStyle(color: Color(0xFF6C63FF))),
                  Expanded(
                    child: Text(
                      line,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFCBD5E1),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Participants.
        if (participants.isNotEmpty) ...[
          SizedBox(height: gap),
          _SectionLabel('Participants · ${participants.length}'),
          const SizedBox(height: AuraSpace.s8),
          ...participants.map((p) => _ParticipantRow(participant: p)),
        ],

        // Materials (attachments) land with file sharing (Phase 5). Until a
        // meeting can actually carry materials, showing an empty placeholder —
        // especially to external guests — advertises an unbuilt feature, so
        // the section stays hidden.
      ],
    );
  }

  String _scheduleLabel(BuildContext context) {
    final scheduledAt = meeting.scheduledAt;
    if (scheduledAt == null) return 'Time will be confirmed by the host';
    final local = scheduledAt.toLocal();
    final loc = MaterialLocalizations.of(context);
    return '${loc.formatFullDate(local)} · '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s12),
        child: child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF9CA3AF),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: AuraSpace.s10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant});
  final MeetingParticipant participant;

  String get _roleLabel => switch (participant.role.toUpperCase()) {
        'HOST' => 'Host',
        'MODERATOR' => 'Moderator',
        'GUEST' => 'Guest',
        _ => 'Participant',
      };

  @override
  Widget build(BuildContext context) {
    final name = participant.displayName.trim();
    final avatar = participant.user?.avatarUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.18),
            backgroundImage: (avatar != null && avatar.trim().isNotEmpty)
                ? NetworkImage(avatar)
                : null,
            child: (avatar == null || avatar.trim().isEmpty)
                ? Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: participant.isHost
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.18)
                  : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _roleLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: participant.isHost
                    ? const Color(0xFFA5B4FC)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.icon, this.logoUrl});
  final String name;
  final String? logoUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.trim().isNotEmpty;
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF111827),
      backgroundImage: hasLogo ? NetworkImage(logoUrl!) : null,
      child: hasLogo
          ? null
          : Icon(icon, color: const Color(0xFFE5E7EB), size: 18),
    );
  }
}
