import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/utils/local_timezone.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';

class CreateMeetingScreen extends ConsumerStatefulWidget {
  final String? institutionId;

  const CreateMeetingScreen({super.key, this.institutionId});

  @override
  ConsumerState<CreateMeetingScreen> createState() =>
      _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends ConsumerState<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _inviteNameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();

  _MeetingPurpose _purpose = _MeetingPurpose.institution;
  bool _startNow = false;
  bool _explicitHostOnly = false;
  DateTime? _scheduledAt;
  int _durationMinutes = 60;
  bool _saving = false;

  bool get _isInstitutionMeeting =>
      widget.institutionId != null && widget.institutionId!.isNotEmpty;

  static const _durations = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    if (!_isInstitutionMeeting) {
      _purpose = _MeetingPurpose.private;
    }
    _applyPurposeDefaults();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _inviteNameCtrl.dispose();
    _inviteEmailCtrl.dispose();
    super.dispose();
  }

  void _applyPurposeDefaults() {
    final defaults = _purpose.defaults(_isInstitutionMeeting);
    _titleCtrl.text = defaults.title;
    _durationMinutes = defaults.durationMinutes;
    _startNow = defaults.startNow;
    _explicitHostOnly = false;
    _scheduledAt = defaults.startNow
        ? null
        : DateTime.now().add(const Duration(hours: 1));
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final contract = _purpose.contract(_isInstitutionMeeting);
    final inviteEmail = _inviteEmailCtrl.text.trim();

    if (!_startNow && _scheduledAt == null) {
      _snack('Pick a date and time.');
      return;
    }
    if (contract.requiresInvitation &&
        inviteEmail.isEmpty &&
        !_explicitHostOnly) {
      _snack('Add an invited recipient or mark this as host-only.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(meetingsRepositoryProvider);
      final meeting = await repo.createMeeting(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        type: _startNow ? 'INSTANT' : 'SCHEDULED',
        intent: contract.intent,
        scheduledAt: _startNow ? null : _scheduledAt!.toUtc().toIso8601String(),
        durationMinutes: _durationMinutes,
        timezone: resolveLocalTimezone(),
        waitingRoomEnabled: contract.waitingRoom,
        allowGuests: contract.allowGuests,
        guestApprovalRequired: contract.guestApprovalRequired,
        organizationId: widget.institutionId,
        audience: _explicitHostOnly ? 'PRIVATE' : contract.audience,
      );

      if (inviteEmail.isNotEmpty) {
        await repo.inviteToMeeting(
          meeting.id,
          name: _inviteNameCtrl.text.trim().isEmpty
              ? null
              : _inviteNameCtrl.text.trim(),
          email: inviteEmail,
        );
      }

      ref.invalidate(meetingWorkspaceProvider(widget.institutionId));
      ref.invalidate(upcomingMeetingsProvider);
      if (widget.institutionId != null) {
        ref.invalidate(
          institutionUpcomingMeetingsProvider(widget.institutionId!),
        );
      }

      if (!mounted) return;
      if (_startNow && meeting.sessionId != null) {
        _showMeetingStarted(context, meeting);
        return;
      }
      context.pushReplacement(_detailPath(meeting.id));
    } catch (_) {
      if (mounted) _snack('Unable to create meeting. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMeetingStarted(BuildContext context, Meeting meeting) {
    final base = _detailPath(meeting.id);
    final live = meeting.sessionId != null
        ? '$base/live?sessionId=${meeting.sessionId}&isHost=true'
        : base;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Instant meeting started'),
        content: Text(_reviewLines().join('\n')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pushReplacement(base);
            },
            child: const Text('Open record'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pushReplacement(live);
            },
            child: const Text('Enter room'),
          ),
        ],
      ),
    );
  }

  String _detailPath(String meetingId) => widget.institutionId == null
      ? '/meetings/$meetingId'
      : '/institution/${widget.institutionId}/meetings/$meetingId';

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final contract = _purpose.contract(_isInstitutionMeeting);
    final dateLabel = _scheduledAt == null
        ? 'Pick date and time'
        : DateFormat('EEE, MMM d, yyyy - h:mm a').format(_scheduledAt!);

    return AuraScaffold(
      title: 'Create meeting',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CreationStep(
                      title: 'Meeting purpose',
                      child: _PurposeGrid(
                        selected: _purpose,
                        institutionMode: _isInstitutionMeeting,
                        onSelected: (purpose) {
                          setState(() {
                            _purpose = purpose;
                            _applyPurposeDefaults();
                          });
                        },
                      ),
                    ),
                    _CreationStep(
                      title: 'Ownership',
                      child: _PlainPanel(
                        icon: _isInstitutionMeeting
                            ? Icons.apartment_rounded
                            : Icons.person_rounded,
                        title: _isInstitutionMeeting
                            ? 'Institution-owned meeting'
                            : 'Personal meeting',
                        body: _isInstitutionMeeting
                            ? 'This meeting belongs to the institution workspace. Institution ownership does not automatically make everyone eligible unless the participation policy says so.'
                            : 'This meeting belongs to your personal meeting workspace.',
                      ),
                    ),
                    _CreationStep(
                      title: 'Participants',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PlainPanel(
                            icon: contract.icon,
                            title: contract.participantTitle,
                            body: contract.participantBody,
                          ),
                          if (contract.requiresInvitation) ...[
                            const SizedBox(height: AuraSpace.s12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _explicitHostOnly,
                              title: const Text(
                                'Host-only preparation meeting',
                              ),
                              subtitle: const Text(
                                'Use this only when no one else is intended to attend.',
                              ),
                              onChanged: (value) =>
                                  setState(() => _explicitHostOnly = value),
                            ),
                            if (!_explicitHostOnly) ...[
                              TextFormField(
                                controller: _inviteEmailCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Invitee email',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (!contract.requiresInvitation ||
                                      _explicitHostOnly) {
                                    return null;
                                  }
                                  final email = value?.trim() ?? '';
                                  if (!email.contains('@')) {
                                    return 'A valid invitee email is required.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              TextFormField(
                                controller: _inviteNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Invitee name (optional)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    _CreationStep(
                      title: 'Access',
                      child: _PlainPanel(
                        icon: Icons.verified_user_rounded,
                        title: _explicitHostOnly
                            ? 'Only the host can enter'
                            : contract.accessTitle,
                        body: _explicitHostOnly
                            ? 'This meeting is intentionally host-only. A shared code or link will not admit other people.'
                            : contract.accessBody,
                      ),
                    ),
                    _CreationStep(
                      title: 'Timing',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.event_rounded),
                                label: Text('Schedule once'),
                              ),
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.video_call_rounded),
                                label: Text('Start now'),
                              ),
                            ],
                            selected: {_startNow},
                            onSelectionChanged: (values) {
                              setState(() {
                                _startNow = values.first;
                                if (!_startNow) {
                                  _scheduledAt ??= DateTime.now().add(
                                    const Duration(hours: 1),
                                  );
                                }
                              });
                            },
                          ),
                          if (!_startNow) ...[
                            const SizedBox(height: AuraSpace.s12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today_rounded),
                              label: Text(dateLabel),
                              onPressed: _pickDateTime,
                            ),
                          ],
                          const SizedBox(height: AuraSpace.s12),
                          DropdownButtonFormField<int>(
                            initialValue: _durationMinutes,
                            decoration: const InputDecoration(
                              labelText: 'Duration',
                              border: OutlineInputBorder(),
                            ),
                            items: _durations
                                .map(
                                  (duration) => DropdownMenuItem(
                                    value: duration,
                                    child: Text(_durationLabel(duration)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _durationMinutes = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    _CreationStep(
                      title: 'Review',
                      child: _ReviewPanel(lines: _reviewLines()),
                    ),
                    const SizedBox(height: AuraSpace.s20),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _startNow
                                    ? Icons.video_call_rounded
                                    : Icons.add_rounded,
                              ),
                        label: Text(
                          _startNow
                              ? 'Start instant meeting'
                              : 'Create meeting',
                        ),
                        onPressed: _saving ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _reviewLines() {
    final contract = _purpose.contract(_isInstitutionMeeting);
    return [
      _isInstitutionMeeting ? 'Owned by institution' : 'Owned by you',
      _explicitHostOnly ? 'Host-only participation' : contract.reviewLine,
      _startNow
          ? 'Starts immediately'
          : _scheduledAt == null
          ? 'Scheduled time not selected'
          : 'Starts ${DateFormat('MMM d, yyyy h:mm a').format(_scheduledAt!)}',
      'Duration $_durationMinutes min',
      if (_inviteEmailCtrl.text.trim().isNotEmpty)
        'Invitation will be sent to ${_inviteEmailCtrl.text.trim()}',
    ];
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}min';
  }
}

enum _MeetingPurpose {
  institution,
  selected,
  private,
  guest,
  oneToOne,
  booking,
  instant,
  custom;

  String get label => switch (this) {
    institution => 'Institution meeting',
    selected => 'Team or selected members',
    private => 'Private meeting',
    guest => 'Client or guest meeting',
    oneToOne => 'One-to-one',
    booking => 'Booking session',
    instant => 'Instant conversation',
    custom => 'Custom',
  };

  IconData get icon => switch (this) {
    institution => Icons.apartment_rounded,
    selected => Icons.groups_rounded,
    private => Icons.lock_rounded,
    guest => Icons.badge_rounded,
    oneToOne => Icons.person_add_alt_rounded,
    booking => Icons.public_rounded,
    instant => Icons.video_call_rounded,
    custom => Icons.tune_rounded,
  };

  _PurposeDefaults defaults(bool institutionMode) => switch (this) {
    institution => const _PurposeDefaults(
      title: 'Institution meeting',
      durationMinutes: 60,
    ),
    selected => const _PurposeDefaults(
      title: 'Selected member meeting',
      durationMinutes: 45,
    ),
    private => const _PurposeDefaults(
      title: 'Private meeting',
      durationMinutes: 30,
    ),
    guest => const _PurposeDefaults(
      title: 'Guest meeting',
      durationMinutes: 30,
    ),
    oneToOne => const _PurposeDefaults(
      title: 'One-to-one',
      durationMinutes: 30,
    ),
    booking => const _PurposeDefaults(
      title: 'Booking session',
      durationMinutes: 30,
    ),
    instant => const _PurposeDefaults(
      title: 'Instant conversation',
      durationMinutes: 30,
      startNow: true,
    ),
    custom => _PurposeDefaults(
      title: institutionMode ? 'Institution meeting' : 'Meeting',
      durationMinutes: 60,
    ),
  };

  _PurposeContract contract(bool institutionMode) => switch (this) {
    institution =>
      institutionMode
          ? const _PurposeContract.institutionWide()
          : const _PurposeContract.privateInvitation(),
    selected => const _PurposeContract.privateInvitation(
      participantTitle: 'Selected people by invitation',
      participantBody:
          'Create a private meeting with explicit invitation evidence for selected participants.',
    ),
    private => const _PurposeContract.privateInvitation(),
    guest => const _PurposeContract.externalGuest(),
    oneToOne => const _PurposeContract.privateInvitation(
      intent: 'ONE_ON_ONE',
      participantTitle: 'One invited person',
      participantBody:
          'Invite the intended person so their link carries participation evidence.',
    ),
    booking => const _PurposeContract.externalGuest(
      intent: 'BOOKING_SESSION',
      participantTitle: 'Booking-backed guest',
      participantBody:
          'For durable public access, manage a booking page from the Meetings workspace. This creates a single scheduled session with guest posture.',
    ),
    instant =>
      institutionMode
          ? const _PurposeContract.institutionWide(
              intent: 'CUSTOM',
              waitingRoom: false,
            )
          : const _PurposeContract.externalGuest(
              intent: 'CUSTOM',
              waitingRoom: false,
            ),
    custom =>
      institutionMode
          ? const _PurposeContract.institutionWide(intent: 'CUSTOM')
          : const _PurposeContract.privateInvitation(intent: 'CUSTOM'),
  };
}

class _PurposeDefaults {
  final String title;
  final int durationMinutes;
  final bool startNow;

  const _PurposeDefaults({
    required this.title,
    required this.durationMinutes,
    this.startNow = false,
  });
}

class _PurposeContract {
  final String intent;
  final String audience;
  final bool allowGuests;
  final bool waitingRoom;
  final bool guestApprovalRequired;
  final bool requiresInvitation;
  final IconData icon;
  final String participantTitle;
  final String participantBody;
  final String accessTitle;
  final String accessBody;
  final String reviewLine;

  const _PurposeContract({
    required this.intent,
    required this.audience,
    required this.allowGuests,
    required this.waitingRoom,
    required this.guestApprovalRequired,
    required this.requiresInvitation,
    required this.icon,
    required this.participantTitle,
    required this.participantBody,
    required this.accessTitle,
    required this.accessBody,
    required this.reviewLine,
  });

  const _PurposeContract.institutionWide({
    this.intent = 'TOWN_HALL',
    this.waitingRoom = true,
  }) : audience = 'INSTITUTION',
       allowGuests = false,
       guestApprovalRequired = true,
       requiresInvitation = false,
       icon = Icons.apartment_rounded,
       participantTitle = 'All active institution members',
       participantBody =
           'Active members can see this meeting in the institution workspace and resolve participation through membership.',
       accessTitle = 'Institution members may attend',
       accessBody =
           'Non-members remain excluded unless independently invited, booked, or allowed as guests by another policy.',
       reviewLine = 'Visible and eligible for all active institution members';

  const _PurposeContract.privateInvitation({
    this.intent = 'CUSTOM',
    this.participantTitle = 'Invited participants only',
    this.participantBody =
        'A private meeting needs explicit invitation evidence or must be intentionally host-only.',
  }) : audience = 'PRIVATE',
       allowGuests = false,
       waitingRoom = true,
       guestApprovalRequired = true,
       requiresInvitation = true,
       icon = Icons.lock_rounded,
       accessTitle = 'Only valid invitees may attend',
       accessBody =
           'The invitation link carries participation evidence. A bare meeting code or link is only a locator.',
       reviewLine = 'Private invited participation';

  const _PurposeContract.externalGuest({
    this.intent = 'CLIENT_MEETING',
    this.waitingRoom = true,
    this.participantTitle = 'External guests',
    this.participantBody =
        'Guests may identify themselves and enter through the resolver-controlled guest path.',
  }) : audience = 'GUEST',
       allowGuests = true,
       guestApprovalRequired = true,
       requiresInvitation = false,
       icon = Icons.badge_rounded,
       accessTitle = 'External guests require host approval',
       accessBody =
           'Guest allowance does not make the meeting public; admission still happens after identity and eligibility resolution.',
       reviewLine = 'External guests allowed with approval';
}

class _CreationStep extends StatelessWidget {
  final String title;
  final Widget child;

  const _CreationStep({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AuraSpace.s10),
          child,
        ],
      ),
    );
  }
}

class _PurposeGrid extends StatelessWidget {
  final _MeetingPurpose selected;
  final bool institutionMode;
  final ValueChanged<_MeetingPurpose> onSelected;

  const _PurposeGrid({
    required this.selected,
    required this.institutionMode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final purposes = _MeetingPurpose.values
        .where(
          (purpose) =>
              institutionMode || purpose != _MeetingPurpose.institution,
        )
        .toList(growable: false);
    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      children: [
        for (final purpose in purposes)
          ChoiceChip(
            avatar: Icon(purpose.icon, size: 18),
            label: Text(purpose.label),
            selected: purpose == selected,
            onSelected: (_) => onSelected(purpose),
          ),
      ],
    );
  }
}

class _PlainPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PlainPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF93C5FD)),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AuraSpace.s6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  final List<String> lines;

  const _ReviewPanel({required this.lines});

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: AuraSpace.s8),
                Expanded(child: Text(line)),
              ],
            ),
            if (line != lines.last) const SizedBox(height: AuraSpace.s8),
          ],
        ],
      ),
    );
  }
}
