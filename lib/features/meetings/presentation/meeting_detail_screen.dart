import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../domain/meeting_asset.dart';
import 'meeting_lifecycle_presenter.dart';
import 'meeting_status_chip.dart';
import 'widgets/meeting_assets_section.dart';
import 'widgets/meeting_section.dart';
import 'widgets/meeting_workroom.dart';

/// THE MEETING RECORD — one page that IS the meeting, before, during, and
/// after. Sections compose by lifecycle state:
///
///  * upcoming  → agenda (editable), participants, schedule actions
///  * live      → enter-room banner, agenda, participants
///  * ended     → the institutional record: summary, outcomes, conversation,
///                attendance (via [MeetingWorkroom]; host edits, members read)
///
/// It absorbs the former detail, /prep, summary, and post-meeting workspace
/// surfaces: those routes all land here now. The live room stays the only
/// separate surface.
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
    final myId = ref.watch(authMeDataProvider).maybeWhen(
          data: (me) {
            final u = me['user'];
            return (u is Map ? (u['id'] ?? '') : (me['id'] ?? ''))
                .toString()
                .trim();
          },
          orElse: () => '',
        );

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: 'Meeting',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Meeting',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 40, color: Color(0xFF6B7280)),
              const SizedBox(height: AuraSpace.s12),
              const Text('This meeting is available to its members.'),
              const SizedBox(height: AuraSpace.s16),
              FilledButton.icon(
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in'),
                onPressed: () => context.go(
                  '/login?redirect=${Uri.encodeComponent('/meetings/$meetingId')}',
                ),
              ),
            ],
          ),
        ),
      ),
      data: (meeting) {
        // OWNERSHIP DOCTRINE: institution meetings are owned by the
        // Institution Workspace end to end. A record reached on a member
        // path (deep link, Desk shortcut, old email link) canonicalizes to
        // its institution URL, which flips the shell to InstitutionShell.
        final owningInstitution = meeting.owningInstitutionId;
        if (institutionId == null &&
            owningInstitution != null &&
            owningInstitution.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/institution/$owningInstitution/meetings/$meetingId');
            }
          });
          return AuraScaffold(
            title: 'Meeting',
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final isHost =
            myId.isNotEmpty && myId == (meeting.host?.id ?? '');
        // Governance: institution admins may cancel the institution's
        // meetings even when another member is the assigned host.
        final identity = ref.watch(institutionIdentityProvider);
        final canGovern = identity != null &&
            identity.isAdmin &&
            identity.id == meeting.owningInstitutionId;
        return _MeetingRecordBody(
          meeting: meeting,
          institutionId: institutionId,
          isHost: isHost,
          canGovern: canGovern,
          lifecycle: MeetingLifecyclePresenter.present(
            meeting,
            room: meeting.room,
            isHost: isHost,
          ),
        );
      },
    );
  }
}

class _MeetingRecordBody extends ConsumerStatefulWidget {
  final Meeting meeting;
  final String? institutionId;
  final bool isHost;

  /// Viewer is an admin of the owning institution: governance actions
  /// (cancel) are available even when someone else hosts.
  final bool canGovern;
  final MeetingLifecycleViewModel lifecycle;

  const _MeetingRecordBody({
    required this.meeting,
    this.institutionId,
    required this.isHost,
    this.canGovern = false,
    required this.lifecycle,
  });

  @override
  ConsumerState<_MeetingRecordBody> createState() => _MeetingRecordBodyState();
}

class _MeetingRecordBodyState extends ConsumerState<_MeetingRecordBody> {
  bool _actioning = false;

  Meeting get meeting => widget.meeting;
  bool get isHost => widget.isHost;
  String? get _resolvedInstitutionId =>
      widget.institutionId ?? meeting.owningInstitutionId;
  String get _liveBasePath => _resolvedInstitutionId == null
      ? '/meetings/${meeting.id}/live'
      : '/institution/${_resolvedInstitutionId!}/meetings/${meeting.id}/live';

  void _enterRoom({String? sessionId}) {
    final sid = sessionId ?? meeting.sessionId;
    if (sid == null || sid.isEmpty) return;
    context.push('$_liveBasePath?sessionId=$sid&isHost=$isHost');
  }

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
      // Starting the meeting takes the host straight into the room — the
      // record is the doorway, the live room is the destination.
      _enterRoom(sessionId: updated.sessionId);
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
                              const SnackBar(
                                content: Text(
                                    'Unable to update meeting. Try again.'),
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

  Future<void> _addToCalendar() async {
    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/public/meetings/${meeting.meetingCode}/calendar.ics',
    );
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch failed');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar link copied')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final lifecycle = widget.lifecycle;
    final ended = meeting.isEnded;
    final live = lifecycle.isLive ||
        lifecycle.status == MeetingLifecycleStatus.hostWaiting ||
        lifecycle.status == MeetingLifecycleStatus.guestWaiting;
    final hasAgenda = (meeting.preparationNotes ?? '').trim().isNotEmpty;

    return AuraScaffold(
      title: 'Meeting',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.canPop()
            ? context.pop()
            : context.go(
                _resolvedInstitutionId == null
                    ? '/meetings'
                    : '/institution/$_resolvedInstitutionId/meetings',
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RecordHeader(
                    meeting: meeting,
                    lifecycle: lifecycle,
                    isHost: isHost,
                    actioning: _actioning,
                    onStart: _startMeeting,
                    onEnter: () => _enterRoom(),
                    onEdit: _editMeeting,
                    onCopy: _copyLink,
                    onCalendar: _addToCalendar,
                    onCancel: _cancelMeeting,
                  ),
                  const SizedBox(height: AuraSpace.s16),

                  // Live doorway — when the room is open, the record's first
                  // job is getting you into it.
                  if (live && !ended) ...[
                    _LiveBanner(
                      participantCount:
                          meeting.room?.activeParticipantCount ?? 0,
                      onEnter:
                          meeting.sessionId == null ? null : () => _enterRoom(),
                    ),
                    const SizedBox(height: AuraSpace.s16),
                  ],

                  // Agenda travels the whole lifecycle: editable before and
                  // during (host), part of the record after.
                  if (!ended && isHost) ...[
                    MeetingSection(
                      title: 'Agenda',
                      child: _PreparationNotesSection(meeting: meeting),
                    ),
                    const SizedBox(height: AuraSpace.s16),
                  ] else if (hasAgenda) ...[
                    MeetingSection(
                      title: 'Agenda',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in meeting.preparationNotes!
                              .trim()
                              .split('\n')
                              .map((l) => l.trim())
                              .where((l) => l.isNotEmpty))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '·  ',
                                    style: TextStyle(
                                      color: Color(0xFF6C63FF),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s16),
                  ],

                  // Materials — the briefing pack. Part of the record for
                  // the whole lifecycle; guests see guest-visible items on
                  // pre-join and in the room.
                  MeetingAssetsSection(
                    meetingId: meeting.id,
                    title: 'Materials',
                    emptyText: ended
                        ? 'No materials were attached to this meeting.'
                        : 'Attach links or briefing documents participants should read before joining.',
                    filter: (a) =>
                        a.stage == 'PREPARATION' &&
                        a.kind != MeetingAssetKind.recording,
                    canManage: isHost && !ended,
                    addStage: 'PREPARATION',
                    hideWhenEmpty: ended,
                  ),
                  const SizedBox(height: AuraSpace.s16),

                  // People — one roster model for members, guests, bookers.
                  _ParticipantsSection(meeting: meeting, ended: ended),
                  const SizedBox(height: AuraSpace.s16),

                  // The record itself — summary, outcomes, conversation.
                  if (ended) ...[
                    MeetingAssetsSection(
                      meetingId: meeting.id,
                      title: 'Shared in meeting',
                      emptyText: 'No files were shared during this meeting.',
                      filter: (a) =>
                          a.stage == 'MEETING' &&
                          a.kind != MeetingAssetKind.recording,
                      canManage: isHost,
                      addStage: 'MEETING',
                      hideWhenEmpty: true,
                    ),
                    const SizedBox(height: AuraSpace.s16),
                    MeetingAssetsSection(
                      meetingId: meeting.id,
                      title: 'Recording',
                      emptyText: 'This meeting was not recorded.',
                      filter: (a) => a.kind == MeetingAssetKind.recording,
                      canManage: isHost,
                      allowAdd: false,
                      hideWhenEmpty: true,
                    ),
                    const SizedBox(height: AuraSpace.s16),
                    MeetingWorkroom(meeting: meeting, editable: isHost),
                    const SizedBox(height: AuraSpace.s16),
                  ],

                  if (!ended && (isHost || widget.canGovern))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel meeting'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                        ),
                        onPressed: _actioning ? null : _cancelMeeting,
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
}

// ---------------------------------------------------------------------------
// Header — identity once, truthful status, state-appropriate actions.
// ---------------------------------------------------------------------------

class _RecordHeader extends StatelessWidget {
  final Meeting meeting;
  final MeetingLifecycleViewModel lifecycle;
  final bool isHost;
  final bool actioning;
  final VoidCallback onStart;
  final VoidCallback onEnter;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onCalendar;
  final VoidCallback onCancel;

  const _RecordHeader({
    required this.meeting,
    required this.lifecycle,
    required this.isHost,
    required this.actioning,
    required this.onStart,
    required this.onEnter,
    required this.onEdit,
    required this.onCopy,
    required this.onCalendar,
    required this.onCancel,
  });

  String _whenLabel(BuildContext context) {
    final state = meeting.state.toUpperCase();
    if (state == 'ACTIVE') return 'Happening now';
    if (state == 'ENDED') return 'This meeting has ended';
    if (state == 'CANCELLED') return 'This meeting was cancelled';
    final scheduled = meeting.scheduledAt;
    if (scheduled == null) return 'Instant meeting';
    final local = scheduled.toLocal();
    final loc = MaterialLocalizations.of(context);
    return '${loc.formatFullDate(local)} at ${TimeOfDay.fromDateTime(local).format(context)} (your time)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ended = meeting.isEnded;
    final scheduled = !ended &&
        meeting.state.toUpperCase() != 'ACTIVE' &&
        meeting.scheduledAt != null;
    final live = meeting.state.toUpperCase() == 'ACTIVE';
    final institution = meeting.booking?.institution;
    final hostName = meeting.host?.name;

    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MeetingStatusChip(lifecycle: lifecycle, viewerIsHost: isHost),
              if (institution != null || meeting.booking != null)
                _SmallChip(
                  icon: Icons.calendar_today_rounded,
                  label: institution?.name ?? 'Guest booking',
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
          const SizedBox(height: AuraSpace.s6),
          Text(
            [
              if (hostName != null) 'Hosted by $hostName',
              _whenLabel(context),
              '${meeting.durationMinutes} min',
            ].join('  ·  '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF9CA3AF),
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
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              if (!ended && isHost && !live)
                FilledButton.icon(
                  icon: const Icon(Icons.video_call_rounded),
                  label: const Text('Start meeting'),
                  onPressed: actioning ? null : onStart,
                ),
              if (live)
                FilledButton.icon(
                  icon: const Icon(Icons.meeting_room_rounded),
                  label: const Text('Enter room'),
                  onPressed: actioning ? null : onEnter,
                ),
              if (!ended)
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_rounded),
                  label: const Text('Invite'),
                  onPressed: onCopy,
                ),
              if (scheduled)
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text('Add to calendar'),
                  onPressed: onCalendar,
                ),
              if (!ended && isHost)
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                  onPressed: actioning ? null : onEdit,
                ),
              if (ended)
                OutlinedButton.icon(
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Copy meeting link'),
                  onPressed: onCopy,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  final int participantCount;
  final VoidCallback? onEnter;

  const _LiveBanner({required this.participantCount, required this.onEnter});

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.45),
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              participantCount > 0
                  ? 'This meeting is live · $participantCount in the room'
                  : 'This meeting is live',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.meeting_room_rounded, size: 18),
            label: const Text('Enter room'),
            onPressed: onEnter,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// People — one roster for members, guests, and invitations.
// ---------------------------------------------------------------------------

class _ParticipantsSection extends StatelessWidget {
  final Meeting meeting;
  final bool ended;

  const _ParticipantsSection({required this.meeting, required this.ended});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final participants = meeting.participants
        .where((p) => p.displayName.trim().isNotEmpty)
        .toList();

    return MeetingSection(
      title: ended ? 'Attendance' : 'Participants',
      trailing: participants.isEmpty
          ? null
          : Text(
              '${participants.length}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF8A94A6)),
            ),
      child: participants.isEmpty
          ? MeetingSection.emptyLine(
              context,
              'No participants yet — share the meeting link to invite people.',
            )
          : Column(
              children: [
                for (final p in participants)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              const Color(0xFF6C63FF).withValues(alpha: 0.18),
                          child: Text(
                            p.displayName.trim()[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s10),
                        Expanded(
                          child: Text(
                            p.displayName,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (p.isHost)
                          const _SmallChip(
                            icon: Icons.star_rounded,
                            label: 'Host',
                          )
                        else if (p.isGuest)
                          const _SmallChip(
                            icon: Icons.person_outline_rounded,
                            label: 'Guest',
                          ),
                        const SizedBox(width: AuraSpace.s10),
                        Text(
                          _attendanceLabel(p),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: p.attended
                                ? const Color(0xFF10B981)
                                : const Color(0xFF8A94A6),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _attendanceLabel(MeetingParticipant p) {
    if (!p.attended) return ended ? 'Did not join' : 'Not joined yet';
    final dur = p.durationMinutes;
    if (!ended) return 'In the meeting';
    if (dur == null) return 'Joined';
    return dur < 1 ? 'Joined · under 1m' : 'Joined · ${dur}m';
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

// ---------------------------------------------------------------------------
// Agenda editor (host, before/during the meeting).
// ---------------------------------------------------------------------------

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
        const SnackBar(content: Text('Agenda saved')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to save the agenda. Try again.')),
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
            hintText:
                'What this meeting is for — talking points, questions, materials to review. Participants see this before joining, and it stays visible in the room.',
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
                : const Text('Save agenda'),
          ),
        ),
      ],
    );
  }
}
