import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import 'meeting_lifecycle_presenter.dart';

class MeetingSummaryScreen extends ConsumerWidget {
  final String meetingId;
  final String? institutionId;

  const MeetingSummaryScreen({
    super.key,
    required this.meetingId,
    this.institutionId,
  });

  String get _postMeetingPath => institutionId == null
      ? '/meetings/$meetingId/post-meeting'
      : '/institution/$institutionId/meetings/$meetingId/post-meeting';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingAsync = ref.watch(meetingProvider(meetingId));
    final summaryAsync = ref.watch(meetingSummaryProvider(meetingId));

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: 'Meeting summary',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Meeting summary',
        body: Center(child: Text('Could not load meeting: $e')),
      ),
      data: (meeting) {
        final room = meeting.room;
        final lifecycle = MeetingLifecyclePresenter.present(
          meeting,
          room: room,
          isHost: true,
        );
        final summary = summaryAsync.valueOrNull ?? meeting.summary;
        final booking = meeting.booking;
        final institutionName =
            booking?.institution?.name ??
            booking?.bookingPageName ??
            meeting.host?.name ??
            'Meeting';

        return AuraScaffold(
          title: 'Meeting summary',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SummaryHeader(
                        meeting: meeting,
                        lifecycle: lifecycle,
                        institutionName: institutionName,
                        onCopy: () => _copyLink(context, meeting),
                        onOpenWorkspace: () => context.push(_postMeetingPath),
                        onOpenRoom:
                            !meeting.isEnded && meeting.sessionId != null
                            ? () => context.push(
                                institutionId == null
                                    ? '/meetings/$meetingId/room?sessionId=${meeting.sessionId}'
                                    : '/institution/$institutionId/meetings/$meetingId/room?sessionId=${meeting.sessionId}',
                              )
                            : null,
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      Wrap(
                        spacing: AuraSpace.s16,
                        runSpacing: AuraSpace.s16,
                        children: [
                          _SummaryPanel(
                            title: 'Attendance',
                            width: 510,
                            children: [
                              _AttendanceRow(
                                label: 'Host',
                                value: meeting.host?.name ?? 'Host',
                                status: 'Host present',
                              ),
                              ...meeting.participants
                                  .where((p) => !p.isHost)
                                  .map(
                                    (participant) => _AttendanceRow(
                                      label: participant.isGuest
                                          ? 'Guest'
                                          : 'Participant',
                                      value: participant.displayName,
                                      status: participant.attended
                                          ? 'Joined'
                                          : 'Not joined',
                                    ),
                                  ),
                            ],
                          ),
                          _SummaryPanel(
                            title: 'Meeting context',
                            width: 510,
                            children: [
                              _InfoRow(
                                icon: Icons.schedule_rounded,
                                label: 'Scheduled',
                                value: _scheduledLabel(context, meeting),
                              ),
                              _InfoRow(
                                icon: Icons.timer_outlined,
                                label: 'Duration',
                                value: '${meeting.durationMinutes} minutes',
                              ),
                              _InfoRow(
                                icon: Icons.public_rounded,
                                label: 'Timezone',
                                value: meeting.timezone,
                              ),
                              _InfoRow(
                                icon: Icons.business_rounded,
                                label: 'Institution',
                                value: institutionName,
                              ),
                              _InfoRow(
                                icon: Icons.link_rounded,
                                label: 'Join link',
                                value: meeting.joinUrl,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _SummaryPanel(
                        title: 'Meeting summary',
                        fullWidth: true,
                        children: [
                          if (summary?.summaryText?.trim().isNotEmpty == true)
                            _InfoRow(
                              icon: Icons.subject_rounded,
                              label: 'Summary',
                              value: summary!.summaryText!.trim(),
                            )
                          else
                            const _EmptyState(
                              title: 'No summary recorded yet',
                              body:
                                  'Open the workspace to capture the meeting summary, decisions, commitments, actions, issues, and follow-ups.',
                            ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _SummaryTile(
                        title: 'Booking source and notes',
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Booking page',
                            value:
                                booking?.bookingPageName?.trim().isNotEmpty ==
                                    true
                                ? booking!.bookingPageName!
                                : 'Not created from a booking page',
                          ),
                          if (booking?.bookerNotes?.trim().isNotEmpty == true)
                            _InfoRow(
                              icon: Icons.notes_rounded,
                              label: 'Guest note',
                              value: booking!.bookerNotes!.trim(),
                            ),
                          if ((meeting.description ?? '').trim().isNotEmpty)
                            _InfoRow(
                              icon: Icons.description_outlined,
                              label: 'Meeting description',
                              value: meeting.description!.trim(),
                            ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _SummaryTile(
                        title: 'Follow-up',
                        children: [
                          _FollowUpBlock(
                            title: 'Decisions',
                            values: summary?.decisions ?? const [],
                            fallback:
                                'Record the decision you reached in the meeting.',
                          ),
                          const SizedBox(height: AuraSpace.s12),
                          _FollowUpBlock(
                            title: 'Commitments',
                            values: summary?.commitments ?? const [],
                            fallback:
                                'Capture anything the host or guest agreed to do next.',
                          ),
                          const SizedBox(height: AuraSpace.s12),
                          _FollowUpBlock(
                            title: 'Actions and next steps',
                            values: summary?.actions ?? const [],
                            fallback:
                                'Track the work that should continue after the meeting.',
                          ),
                          const SizedBox(height: AuraSpace.s12),
                          _FollowUpBlock(
                            title: 'Issues',
                            values: summary?.issues ?? const [],
                            fallback: 'Record any blockers or open questions.',
                          ),
                          const SizedBox(height: AuraSpace.s12),
                          _FollowUpBlock(
                            title: 'Follow-ups',
                            values: summary?.followUps ?? const [],
                            fallback:
                                'Record the next check-in, reply, or milestone.',
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      if (!meeting.isEnded)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            border: Border.all(color: const Color(0xFF243244)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AuraSpace.s16),
                            child: Text(
                              'This meeting is still active. The summary will continue to update while the room remains open.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF9CA3AF)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyLink(BuildContext context, Meeting meeting) {
    Clipboard.setData(ClipboardData(text: meeting.joinUrl));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meeting link copied')));
  }
}

class _SummaryHeader extends StatelessWidget {
  final Meeting meeting;
  final MeetingLifecycleViewModel lifecycle;
  final String institutionName;
  final VoidCallback onCopy;
  final VoidCallback onOpenWorkspace;
  final VoidCallback? onOpenRoom;

  const _SummaryHeader({
    required this.meeting,
    required this.lifecycle,
    required this.institutionName,
    required this.onCopy,
    required this.onOpenWorkspace,
    required this.onOpenRoom,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(lifecycle: lifecycle),
                if (meeting.booking != null)
                  const _SmallChip(
                    icon: Icons.calendar_today_rounded,
                    label: 'Guest booking',
                  ),
              ],
            ),
            const SizedBox(height: AuraSpace.s12),
            Text(
              meeting.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AuraSpace.s8),
            Text(
              institutionName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
            ),
            if ((meeting.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s8),
              Text(
                meeting.description!.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFCBD5E1),
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.s16),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Open post-meeting workspace'),
                  onPressed: onOpenWorkspace,
                ),
                if (onOpenRoom != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.meeting_room_rounded),
                    label: const Text('Open room'),
                    onPressed: onOpenRoom,
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Copy meeting link'),
                  onPressed: onCopy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double? width;
  final bool fullWidth;

  const _SummaryPanel({
    required this.title,
    required this.children,
    this.width,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final panelWidth = fullWidth ? double.infinity : width ?? 480;
    return SizedBox(
      width: panelWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: const Color(0xFF243244)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AuraSpace.s12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SummaryTile({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s18,
          vertical: AuraSpace.s4,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AuraSpace.s18,
          0,
          AuraSpace.s18,
          AuraSpace.s18,
        ),
        collapsedIconColor: const Color(0xFF9CA3AF),
        iconColor: const Color(0xFF9CA3AF),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        children: children,
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final String label;
  final String value;
  final String status;

  const _AttendanceRow({
    required this.label,
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label · $value',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            status,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$title: $body',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
    );
  }
}

class _FollowUpBlock extends StatelessWidget {
  final String title;
  final List<String> values;
  final String fallback;

  const _FollowUpBlock({
    required this.title,
    required this.values,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AuraSpace.s6),
            if (values.isEmpty)
              Text(
                fallback,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9CA3AF),
                ),
              )
            else
              ...values.map(
                (value) => Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s6),
                  child: Text(
                    '• $value',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MeetingLifecycleViewModel lifecycle;

  const _StatusChip({required this.lifecycle});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (lifecycle.status) {
      MeetingLifecycleStatus.scheduled => (
        'Scheduled',
        const Color(0xFF6C63FF),
      ),
      MeetingLifecycleStatus.startingSoon => (
        'Starting soon',
        const Color(0xFF8B85FF),
      ),
      MeetingLifecycleStatus.guestWaiting => (
        'Guest waiting',
        const Color(0xFFF59E0B),
      ),
      MeetingLifecycleStatus.hostWaiting => (
        'Host waiting',
        const Color(0xFFF59E0B),
      ),
      MeetingLifecycleStatus.inProgress => (
        'In progress',
        const Color(0xFF10B981),
      ),
      MeetingLifecycleStatus.ended => ('Ended', const Color(0xFF9CA3AF)),
      MeetingLifecycleStatus.missed => ('Missed', const Color(0xFF9CA3AF)),
      MeetingLifecycleStatus.cancelled => (
        'Cancelled',
        const Color(0xFFEF4444),
      ),
      MeetingLifecycleStatus.connectionIssue => (
        'Connection issue',
        const Color(0xFFF97316),
      ),
      MeetingLifecycleStatus.unknown => ('Scheduled', const Color(0xFF9CA3AF)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _scheduledLabel(BuildContext context, Meeting meeting) {
  final scheduledAt = meeting.scheduledAt;
  if (scheduledAt == null) return 'Time will be confirmed by the host';
  final local = scheduledAt.toLocal();
  return '${MaterialLocalizations.of(context).formatFullDate(local)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
