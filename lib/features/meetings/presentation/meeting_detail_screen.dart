import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import 'meeting_lifecycle_presenter.dart';

class MeetingDetailScreen extends ConsumerWidget {
  final String meetingId;
  final String? institutionId;

  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
    this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingAsync = ref.watch(meetingProvider(meetingId));

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: 'Meeting',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Meeting',
        body: Center(child: Text('Could not load meeting: $e')),
      ),
      data: (meeting) => _MeetingDetailBody(
        meeting: meeting,
        institutionId: institutionId,
        lifecycle: MeetingLifecyclePresenter.present(
          meeting,
          room: meeting.room,
          isHost: true,
        ),
      ),
    );
  }
}

class _MeetingDetailBody extends ConsumerStatefulWidget {
  final Meeting meeting;
  final String? institutionId;
  final MeetingLifecycleViewModel lifecycle;

  const _MeetingDetailBody({
    required this.meeting,
    this.institutionId,
    required this.lifecycle,
  });

  @override
  ConsumerState<_MeetingDetailBody> createState() => _MeetingDetailBodyState();
}

class _MeetingDetailBodyState extends ConsumerState<_MeetingDetailBody> {
  bool _actioning = false;

  Meeting get meeting => widget.meeting;
  String? get _resolvedInstitutionId =>
      widget.institutionId ?? meeting.booking?.institution?.id;
  String get _roomBasePath => _resolvedInstitutionId == null
      ? '/meetings/${meeting.id}/room'
      : '/institution/${_resolvedInstitutionId!}/meetings/${meeting.id}/room';
  String get _roomPath => _roomBasePath;
  String get _meetingRoomReturnTo => Uri.encodeComponent(_roomBasePath);
  String get _summaryPath => _resolvedInstitutionId == null
      ? '/meetings/${meeting.id}/summary'
      : '/institution/${_resolvedInstitutionId!}/meetings/${meeting.id}/summary';

  Future<void> _startMeeting() async {
    setState(() => _actioning = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref
          .read(meetingsRepositoryProvider)
          .startMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      _invalidateLists();
      if (!mounted) return;
      if (updated.sessionId != null) {
        context.push(
          '$_roomPath?sessionId=${updated.sessionId}&returnTo=$_meetingRoomReturnTo',
        );
      } else {
        context.push(_roomPath);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start meeting: $e')),
      );
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _cancelMeeting() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel meeting?'),
        content: const Text(
          'The meeting will be cancelled for the host and guest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep meeting'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel meeting'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _actioning = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(meetingsRepositoryProvider).cancelMeeting(meeting.id);
      ref.invalidate(meetingProvider(meeting.id));
      _invalidateLists();
      if (!mounted) return;
      router.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not cancel meeting: $e')),
      );
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: meeting.joinUrl));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meeting link copied')));
  }

  void _invalidateLists() {
    final institutionId = _resolvedInstitutionId;
    if (institutionId == null) {
      ref.invalidate(upcomingMeetingsProvider);
      ref.invalidate(pastMeetingsProvider);
    } else {
      ref.invalidate(institutionUpcomingMeetingsProvider(institutionId));
      ref.invalidate(institutionPastMeetingsProvider(institutionId));
    }
  }

  void _joinMeeting() {
    if (meeting.sessionId != null) {
      context.push(
        '$_roomPath?sessionId=${meeting.sessionId}&returnTo=$_meetingRoomReturnTo',
      );
    } else {
      context.push(_roomPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final booking = meeting.booking;
    final guest = _guestParticipant;
    final institutionId = _resolvedInstitutionId;

    return AuraScaffold(
      title: institutionId == null ? 'Meeting details' : 'Institution meeting',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderCard(
                    meeting: meeting,
                    lifecycle: widget.lifecycle,
                    onStart: _actioning ? null : _startMeeting,
                    onJoin: _actioning ? null : _joinMeeting,
                    onCopy: _copyLink,
                    onOpenSummary: () => context.push(_summaryPath),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  Wrap(
                    spacing: AuraSpace.s16,
                    runSpacing: AuraSpace.s16,
                    children: [
                      _InfoPanel(
                        title: 'Meeting details',
                        children: [
                          _InfoRow(
                            icon: Icons.schedule_rounded,
                            label: 'Date and time',
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
                            icon: Icons.link_rounded,
                            label: 'Meeting link',
                            value: meeting.joinUrl,
                            onTap: _copyLink,
                            trailing: const Icon(
                              Icons.content_copy_rounded,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      _InfoPanel(
                        title: 'Attendee details',
                        children: [
                          _InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Guest',
                            value:
                                booking?.bookerName ??
                                guest?.displayName ??
                                'No guest yet',
                          ),
                          if ((booking?.bookerEmail ?? guest?.guestEmail)
                                  ?.isNotEmpty ==
                              true)
                            _InfoRow(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              value: booking?.bookerEmail ?? guest!.guestEmail!,
                            ),
                          _InfoRow(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Guest status',
                            value: guest?.attended == true
                                ? 'Guest has joined'
                                : 'Guest has not joined yet',
                          ),
                          if (booking?.bookerNotes?.trim().isNotEmpty == true)
                            _InfoRow(
                              icon: Icons.notes_rounded,
                              label: 'Guest note',
                              value: booking!.bookerNotes!.trim(),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  _InfoPanel(
                    title: 'Source',
                    fullWidth: true,
                    children: [
                      if (booking?.institution != null)
                        _InfoRow(
                          icon: Icons.business_rounded,
                          label: 'Institution',
                          value: booking!.institution!.name,
                        ),
                      if ((booking?.institution?.tagline ?? '').trim().isNotEmpty)
                        _InfoRow(
                          icon: Icons.verified_outlined,
                          label: 'Tagline',
                          value: booking!.institution!.tagline!.trim(),
                        ),
                      if ((booking?.institution?.description ?? '')
                              .trim()
                              .isNotEmpty ==
                          true)
                        _InfoRow(
                          icon: Icons.description_outlined,
                          label: 'About',
                          value: booking!.institution!.description!.trim(),
                        ),
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Booking page',
                        value:
                            booking?.bookingPageName?.trim().isNotEmpty == true
                            ? booking!.bookingPageName!
                            : 'Not created from a booking page',
                      ),
                      if (booking?.host != null)
                        _InfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Assigned host',
                          value: [
                            booking!.host!.name,
                            if (booking.host!.title?.trim().isNotEmpty == true)
                              booking.host!.title!.trim(),
                          ].join(' · '),
                        ),
                          _InfoRow(
                            icon: Icons.person_pin_circle_outlined,
                            label: 'Host',
                            value: [
                              meeting.host?.name ?? 'Host',
                              if (meeting.host?.title?.trim().isNotEmpty == true)
                                meeting.host!.title!.trim(),
                            ].join(' · '),
                          ),
                      _InfoRow(
                        icon: Icons.mark_email_read_outlined,
                        label: 'Email status',
                        value: booking == null
                            ? 'No guest confirmation for this meeting'
                            : 'Confirmation sent when the guest booked',
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        'Preparation notes',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AuraSpace.s12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          border: Border.all(color: const Color(0xFF243244)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Add notes, prep points, and follow-up items here.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      Text(
                        'Waiting and attendance',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AuraSpace.s12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          border: Border.all(color: const Color(0xFF243244)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          guest?.attended == true
                              ? 'Guest has joined the meeting.'
                              : 'Waiting for the guest to join.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (meeting.summary != null) ...[
                    const SizedBox(height: AuraSpace.s16),
                    _InfoPanel(
                      title: 'Meeting summary',
                      fullWidth: true,
                      children: [
                        if (meeting.summary?.summaryText?.trim().isNotEmpty ==
                            true)
                          _InfoRow(
                            icon: Icons.subject_rounded,
                            label: 'Summary',
                            value: meeting.summary!.summaryText!.trim(),
                          ),
                        if (meeting.summary?.decisions.isNotEmpty == true)
                          _ListRow(
                            title: 'Decisions',
                            values: meeting.summary!.decisions,
                          ),
                        if (meeting.summary?.commitments.isNotEmpty == true)
                          _ListRow(
                            title: 'Commitments',
                            values: meeting.summary!.commitments,
                          ),
                        if (meeting.summary?.actions.isNotEmpty == true)
                          _ListRow(
                            title: 'Actions',
                            values: meeting.summary!.actions,
                          ),
                        if (meeting.summary?.followUps.isNotEmpty == true)
                          _ListRow(
                            title: 'Follow-ups',
                            values: meeting.summary!.followUps,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AuraSpace.s16),
                  if (!meeting.isEnded)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel meeting'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade500,
                      ),
                      onPressed: _actioning ? null : _cancelMeeting,
                    ),
                  if (meeting.isEnded)
                    Text(
                      'This meeting is ${meeting.state == 'CANCELLED' ? 'cancelled' : 'completed'}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  const SizedBox(height: AuraSpace.s32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  MeetingParticipant? get _guestParticipant {
    for (final participant in meeting.participants) {
      if (participant.isGuest) return participant;
    }
    return null;
  }
}

class _HeaderCard extends StatelessWidget {
  final Meeting meeting;
  final MeetingLifecycleViewModel lifecycle;
  final VoidCallback? onStart;
  final VoidCallback? onJoin;
  final VoidCallback onCopy;
  final VoidCallback onOpenSummary;

  const _HeaderCard({
    required this.meeting,
    required this.lifecycle,
    required this.onStart,
    required this.onJoin,
    required this.onCopy,
    required this.onOpenSummary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
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
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (meeting.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AuraSpace.s8),
              Text(
                meeting.description!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9CA3AF),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.s18),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                _LifecycleActionButton(
                  lifecycle: lifecycle,
                  onStart: onStart,
                  onJoin: onJoin,
                  onOpenSummary: onOpenSummary,
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

class _InfoPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool fullWidth;

  const _InfoPanel({
    required this.title,
    required this.children,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = fullWidth
        ? double.infinity
        : width >= 900
        ? 482.0
        : double.infinity;

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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s8),
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
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final String title;
  final List<String> values;

  const _ListRow({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AuraSpace.s6),
          ...values.map(
            (value) => Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s4),
              child: Text(
                '• $value',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
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
      MeetingLifecycleStatus.ended => ('Completed', const Color(0xFF9CA3AF)),
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

class _LifecycleActionButton extends StatelessWidget {
  final MeetingLifecycleViewModel lifecycle;
  final VoidCallback? onStart;
  final VoidCallback? onJoin;
  final VoidCallback onOpenSummary;

  const _LifecycleActionButton({
    required this.lifecycle,
    required this.onStart,
    required this.onJoin,
    required this.onOpenSummary,
  });

  @override
  Widget build(BuildContext context) {
    final label = lifecycle.primaryAction;
    if (label == 'View summary' || label == 'Review missed') {
      return FilledButton.icon(
        icon: const Icon(Icons.description_outlined),
        label: Text(label),
        onPressed: onOpenSummary,
      );
    }
    if (label == 'Retry connection') {
      return FilledButton.icon(
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry connection'),
        onPressed: onJoin ?? onStart,
      );
    }
    if (label == 'Enter room') {
      return FilledButton.icon(
        icon: const Icon(Icons.video_call_rounded),
        label: const Text('Enter room'),
        onPressed: onJoin,
      );
    }
    return FilledButton.icon(
      icon: const Icon(Icons.video_call_rounded),
      label: const Text('Start meeting'),
      onPressed: onStart,
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
        color: const Color(0xFF6C63FF).withValues(alpha: 0.10),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.30),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8B85FF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD9D7FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _scheduledLabel(BuildContext context, Meeting meeting) {
  final scheduled = meeting.scheduledAt;
  if (scheduled == null) return 'Instant meeting';
  final local = scheduled.toLocal();
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatFullDate(local);
  final time = TimeOfDay.fromDateTime(local).format(context);
  return '$date at $time';
}
