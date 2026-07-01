import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../domain/meeting_identity.dart';
import 'meeting_lifecycle_presenter.dart';
import 'meeting_status_chip.dart';

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
        title: 'Meeting details',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Meeting details',
        body: const Center(child: Text('Unable to load meeting details.')),
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
        const SnackBar(content: Text('Unable to start meeting. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _editMeeting() async {
    final titleCtrl = TextEditingController(text: meeting.title);
    final descCtrl = TextEditingController(text: meeting.description ?? '');
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    DateTime? scheduledAt = meeting.scheduledAt;
    var durationMinutes = meeting.durationMinutes;
    var waitingRoomEnabled = meeting.waitingRoomEnabled;
    var allowGuests = meeting.allowGuests;
    var saving = false;

    Future<void> pickDateTime(
      BuildContext pickerContext,
      StateSetter setDialogState,
    ) async {
      final now = DateTime.now();
      final base = scheduledAt ?? now.add(const Duration(hours: 1));
      final date = await showDatePicker(
        context: pickerContext,
        initialDate: base,
        firstDate: now.subtract(const Duration(days: 1)),
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null || !pickerContext.mounted) return;
      final time = await showTimePicker(
        context: pickerContext,
        initialTime: TimeOfDay.fromDateTime(base),
      );
      if (time == null || !pickerContext.mounted) return;
      setDialogState(() {
        scheduledAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final scheduledLabel = scheduledAt == null
                ? 'Pick date and time'
                : '${MaterialLocalizations.of(dialogContext).formatFullDate(scheduledAt!.toLocal())} at ${MaterialLocalizations.of(dialogContext).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt!.toLocal()))}';
            return AlertDialog(
              title: const Text('Edit meeting'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Meeting title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(scheduledLabel),
                        onPressed: () =>
                            pickDateTime(dialogContext, setDialogState),
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      DropdownButtonFormField<int>(
                        initialValue: durationMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                          border: OutlineInputBorder(),
                        ),
                        items: const [15, 30, 45, 60, 90, 120]
                            .map(
                              (minutes) => DropdownMenuItem(
                                value: minutes,
                                child: Text('$minutes min'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => durationMinutes = value);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Waiting room'),
                        value: waitingRoomEnabled,
                        onChanged: (value) =>
                            setDialogState(() => waitingRoomEnabled = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow guests'),
                        value: allowGuests,
                        onChanged: (value) =>
                            setDialogState(() => allowGuests = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (scheduledAt == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please pick a date and time'),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            await ref
                                .read(meetingsRepositoryProvider)
                                .updateMeeting(
                                  meeting.id,
                                  title: titleCtrl.text.trim(),
                                  description: descCtrl.text.trim().isEmpty
                                      ? null
                                      : descCtrl.text.trim(),
                                  scheduledAt: scheduledAt!
                                      .toUtc()
                                      .toIso8601String(),
                                  durationMinutes: durationMinutes,
                                  timezone: meeting.timezone,
                                  waitingRoomEnabled: waitingRoomEnabled,
                                  allowGuests: allowGuests,
                                );
                            ref.invalidate(meetingProvider(meeting.id));
                            _invalidateLists();
                            if (!mounted) return;
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Meeting updated')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text('Unable to update meeting. Try again.'),
                              ),
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    descCtrl.dispose();
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
      // Navigate to a guaranteed-valid destination rather than a bare pop().
      // On web, a detail page opened via a direct link has no navigation stack,
      // so router.pop() pops the only route and renders a blank page. Going to
      // the meetings list always resolves to a real screen.
      final listPath = _resolvedInstitutionId == null
          ? '/meetings'
          : '/institution/$_resolvedInstitutionId/meetings';
      router.go(listPath);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to cancel meeting. Try again.')),
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
    final bookerIdentity = booking?.bookerIdentity;

    return AuraScaffold(
      title: 'Meeting details',
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
                    onEdit: _actioning ? null : _editMeeting,
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
                          if (bookerIdentity != null)
                            _IdentityRow(identity: bookerIdentity),
                          _InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Guest',
                            value:
                                bookerIdentity?.displayName ??
                                booking?.bookerName ??
                                guest?.displayName ??
                                'No guest yet',
                          ),
                          if ((bookerIdentity?.email ??
                                      booking?.bookerEmail ??
                                      guest?.guestEmail)
                                  ?.isNotEmpty ==
                              true)
                            _InfoRow(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              value:
                                  bookerIdentity?.email ??
                                  booking?.bookerEmail ??
                                  guest!.guestEmail!,
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
                      _PreparationNotesSection(meeting: meeting),
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
  final VoidCallback? onEdit;
  final VoidCallback? onJoin;
  final VoidCallback onCopy;
  final VoidCallback onOpenSummary;

  const _HeaderCard({
    required this.meeting,
    required this.lifecycle,
    required this.onStart,
    required this.onEdit,
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
                MeetingStatusChip(lifecycle: lifecycle),
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
                if (onEdit != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit meeting'),
                    onPressed: onEdit,
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

class _IdentityRow extends StatelessWidget {
  final MeetingIdentityRef identity;

  const _IdentityRow({required this.identity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.18),
            backgroundImage:
                identity.avatarUrl != null &&
                    identity.avatarUrl!.trim().isNotEmpty
                ? NetworkImage(identity.avatarUrl!)
                : null,
            child:
                identity.avatarUrl == null || identity.avatarUrl!.trim().isEmpty
                ? Text(
                    identity.displayName.trim().isEmpty
                        ? 'G'
                        : identity.displayName.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              [
                identity.displayName,
                if (identity.email.trim().isNotEmpty) identity.email.trim(),
                if (identity.title?.trim().isNotEmpty == true)
                  identity.title!.trim(),
              ].join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
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
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
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
    if (label == 'View summary') {
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

class _PreparationNotesSection extends ConsumerStatefulWidget {
  final Meeting meeting;

  const _PreparationNotesSection({required this.meeting});

  @override
  ConsumerState<_PreparationNotesSection> createState() =>
      _PreparationNotesSectionState();
}

class _PreparationNotesSectionState
    extends ConsumerState<_PreparationNotesSection> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.meeting.preparationNotes ?? '',
    );
  }

  @override
  void didUpdateWidget(_PreparationNotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meeting.preparationNotes !=
        widget.meeting.preparationNotes) {
      _ctrl.text = widget.meeting.preparationNotes ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(meetingsRepositoryProvider).updateMeeting(
        widget.meeting.id,
        preparationNotes: _ctrl.text.trim(),
      );
      ref.invalidate(meetingProvider(widget.meeting.id));
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Preparation notes saved')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to save notes. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Add notes, prep points, and follow-up items here.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save notes'),
          ),
        ),
      ],
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
