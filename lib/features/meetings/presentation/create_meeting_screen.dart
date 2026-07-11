import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/utils/local_timezone.dart';
import '../../institutions/data/institutions_repository.dart';
import '../../institutions/domain/institution.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';
import '../domain/meeting_identity.dart';

final _institutionDetailProvider =
    FutureProvider.family<Institution, String>((ref, institutionId) {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.getById(institutionId);
});

final _institutionMembersProvider = FutureProvider.family<_InstitutionMembersData,
    String>((ref, institutionId) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  final data = await repo.listMembers(institutionId);
  final callerRole = (data['callerRole'] ?? '').toString().trim();
  final rawMembers = data['members'];
  final members = <_InstitutionMember>[];
  if (rawMembers is List) {
    for (final entry in rawMembers.whereType<Map>()) {
      final member = Map<String, dynamic>.from(entry);
      final user = member['user'] is Map
          ? Map<String, dynamic>.from(member['user'] as Map)
          : const <String, dynamic>{};
      final userId = (member['userId'] ?? '').toString().trim();
      if (userId.isEmpty) continue;
      members.add(
        _InstitutionMember(
          userId: userId,
          displayName: (user['displayName'] ?? '').toString().trim(),
          handle: (user['handle'] ?? '').toString().trim(),
          title: (member['title'] ?? '').toString().trim(),
          role: (member['role'] ?? 'MEMBER').toString().trim(),
          canSpeakOfficially: member['canSpeakOfficially'] == true,
        ),
      );
    }
  }
  return _InstitutionMembersData(
    callerRole: callerRole,
    members: members,
  );
});

class CreateMeetingScreen extends ConsumerStatefulWidget {
  final String? institutionId;
  final bool startNow;

  const CreateMeetingScreen({
    super.key,
    this.institutionId,
    this.startNow = false,
  });

  @override
  ConsumerState<CreateMeetingScreen> createState() =>
      _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends ConsumerState<CreateMeetingScreen> {
  final _titleCtrl = TextEditingController();
  final _agendaCtrl = TextEditingController();
  final _memberSearchCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _inviteNameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();

  bool _saving = false;
  bool _startNow = false;
  bool _hostOnly = false;
  bool _includeAllMembers = false;
  int _durationMinutes = 60;
  DateTime? _scheduledAt;
  final Set<String> _selectedMemberIds = <String>{};
  final List<_DraftInvitee> _invitees = <_DraftInvitee>[];

  static const _durations = [15, 30, 45, 60, 90, 120];

  bool get _isInstitutionMode =>
      widget.institutionId != null && widget.institutionId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _startNow = widget.startNow;
    _scheduledAt = _startNow
        ? null
        : DateTime.now().add(const Duration(hours: 1));
    _titleCtrl.text = 'Meeting';
    _agendaCtrl.text = '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _agendaCtrl.dispose();
    _memberSearchCtrl.dispose();
    _inviteCtrl.dispose();
    _inviteNameCtrl.dispose();
    _inviteEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
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

  void _toggleMember(String userId) {
    setState(() {
      if (_selectedMemberIds.contains(userId)) {
        _selectedMemberIds.remove(userId);
      } else {
        _selectedMemberIds.add(userId);
      }
      if (_selectedMemberIds.isNotEmpty) {
        _hostOnly = false;
      }
    });
  }

  void _addInviteeFromInline() {
    final name = _inviteNameCtrl.text.trim();
    final email = _inviteEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;
    _addInvitee(name: name, email: email);
    _inviteNameCtrl.clear();
    _inviteEmailCtrl.clear();
  }

  void _addInviteesFromText() {
    final raw = _inviteCtrl.text.trim();
    if (raw.isEmpty) return;

    final entries = raw
        .split(RegExp(r'[\n,;]+'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    for (final entry in entries) {
      final parsed = _parseInvitee(entry);
      if (parsed != null) {
        _addInvitee(name: parsed.name, email: parsed.email);
      }
    }

    _inviteCtrl.clear();
    setState(() {});
  }

  void _addInvitee({required String name, required String email}) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) return;
    if (_invitees.any((invitee) => invitee.email == normalizedEmail)) return;
    setState(() {
      _invitees.add(_DraftInvitee(name: name.trim(), email: normalizedEmail));
      _hostOnly = false;
    });
  }

  void _editInviteeName(_DraftInvitee invitee) async {
    final ctrl = TextEditingController(text: invitee.name);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invitee name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null) return;
    setState(() {
      invitee.name = value;
    });
  }

  _ParsedInvitee? _parseInvitee(String entry) {
    final match = RegExp(r'^(.*?)<([^<>@]+@[^<>@]+)>$').firstMatch(entry);
    if (match != null) {
      return _ParsedInvitee(
        name: match.group(1)?.trim() ?? '',
        email: match.group(2)!.trim().toLowerCase(),
      );
    }
    if (entry.contains('@')) {
      return _ParsedInvitee(name: '', email: entry.trim().toLowerCase());
    }
    return null;
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('Add a meeting title.');
      return;
    }

    if (!_startNow && _scheduledAt == null) {
      _snack('Pick a date and time.');
      return;
    }

    if (!_hostOnly &&
        !_includeAllMembers &&
        _selectedMemberIds.isEmpty &&
        _invitees.isEmpty) {
      _snack('Select participants, add invitees, or mark this as host-only.');
      return;
    }

    if (_invitees.any((invitee) => invitee.name.trim().isEmpty)) {
      _snack('Complete every external invitee name before creating.');
      return;
    }

    if (!_isInstitutionMode &&
        (_includeAllMembers || _selectedMemberIds.isNotEmpty)) {
      _snack('Institution participants require an institution meeting.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(meetingsRepositoryProvider);
      final meeting = await repo.createMeeting(
        title: title,
        description: _agendaCtrl.text.trim().isEmpty
            ? null
            : _agendaCtrl.text.trim(),
        type: _startNow ? 'INSTANT' : 'SCHEDULED',
        scheduledAt: _startNow ? null : _scheduledAt!.toUtc().toIso8601String(),
        durationMinutes: _durationMinutes,
        timezone: resolveLocalTimezone(),
        waitingRoomEnabled: !_startNow,
        allowGuests: false,
        guestApprovalRequired: false,
        organizationId: widget.institutionId,
        hostOnly: _hostOnly,
        includeAllMembers: _includeAllMembers,
        participantUserIds:
            _includeAllMembers ? const [] : _selectedMemberIds.toList(),
        externalInvitees: _invitees
            .map(
              (invitee) => <String, dynamic>{
                'name': invitee.name.trim(),
                'email': invitee.email.trim(),
              },
            )
            .toList(growable: false),
      );

      ref.invalidate(upcomingMeetingsProvider);
      ref.invalidate(pastMeetingsProvider);
      if (widget.institutionId != null) {
        ref.invalidate(
          institutionUpcomingMeetingsProvider(widget.institutionId!),
        );
        ref.invalidate(institutionPastMeetingsProvider(widget.institutionId!));
      }

      if (!mounted) return;
      if (_startNow && meeting.sessionId != null) {
        context.pushReplacement(_detailPath(meeting.id));
        return;
      }
      context.pushReplacement(_detailPath(meeting.id));
    } catch (_) {
      if (mounted) _snack('Unable to create meeting. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _detailPath(String meetingId) => widget.institutionId == null
      ? '/home'
      : '/institution/${widget.institutionId}/meetings/$meetingId';

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyCurrentInviteeLine() async {
    if (_inviteNameCtrl.text.trim().isEmpty ||
        _inviteEmailCtrl.text.trim().isEmpty) {
      _snack('Add a name and email first.');
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text:
            '${_inviteNameCtrl.text.trim()} <${_inviteEmailCtrl.text.trim()}>',
      ),
    );
    _snack('Invitee copied');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInstitutionMode) {
      return AuraScaffold(
        title: 'Meetings',
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AuraCard(
              padding: const EdgeInsets.all(AuraSpace.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meetings are created inside an institution workspace.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Open an institution to create or start a meeting.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  FilledButton.icon(
                    icon: const Icon(Icons.apartment_rounded),
                    label: const Text('Browse institutions'),
                    onPressed: () => context.push('/institutions'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final membersAsync = widget.institutionId == null
        ? null
        : ref.watch(_institutionMembersProvider(widget.institutionId!));
    final institutionAsync = widget.institutionId == null
        ? null
        : ref.watch(_institutionDetailProvider(widget.institutionId!));
    final bookingIdentity = ref.watch(currentBookingIdentityProvider);
    final bookingProfiles = ref.watch(myAvailabilityProfilesProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 960;
    final dateLabel = _scheduledAt == null
        ? 'Pick date and time'
        : DateFormat('EEE, MMM d, yyyy - h:mm a').format(_scheduledAt!);
    final selectedMembers = membersAsync?.maybeWhen(
          data: (data) {
            final map = <String, _InstitutionMember>{
              for (final member in data.members) member.userId: member,
            };
            return _selectedMemberIds
                .map((id) => map[id])
                .whereType<_InstitutionMember>()
                .toList(growable: false);
          },
          orElse: () => const <_InstitutionMember>[],
        ) ??
        const <_InstitutionMember>[];
    final selectedSummary = selectedMembers.isEmpty
        ? 'No internal members selected'
        : selectedMembers.map((member) => member.displayLabel).join(', ');

    return AuraScaffold(
      title: 'Create meeting',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create meeting',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: AuraSpace.s6),
                  Text(
                    'Set the title, participants, agenda, and timing. Internal participants are bound at creation.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                  ),
                  const SizedBox(height: AuraSpace.s20),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _CreationForm(
                            titleCtrl: _titleCtrl,
                            agendaCtrl: _agendaCtrl,
                            durationMinutes: _durationMinutes,
                            startNow: _startNow,
                            hostOnly: _hostOnly,
                            includeAllMembers: _includeAllMembers,
                            scheduledLabel: dateLabel,
                            onPickDateTime: _pickDateTime,
                            onDurationChanged: (value) =>
                                setState(() => _durationMinutes = value),
                            onStartNowChanged: (value) =>
                                setState(() => _startNow = value),
                            onHostOnlyChanged: (value) =>
                                setState(() => _hostOnly = value),
                            onAllMembersChanged: (value) =>
                                setState(() => _includeAllMembers = value),
                            institutionMode: _isInstitutionMode,
                            bookingIdentity: bookingIdentity.maybeWhen(
                              data: (value) => value,
                              orElse: () => null,
                            ),
                            bookingProfiles: bookingProfiles.maybeWhen(
                              data: (value) => value,
                              orElse: () => const [],
                            ),
                            membersAsync: membersAsync,
                            memberSearchCtrl: _memberSearchCtrl,
                            inviteCtrl: _inviteCtrl,
                            inviteNameCtrl: _inviteNameCtrl,
                            inviteEmailCtrl: _inviteEmailCtrl,
                            invitees: _invitees,
                            selectedSummary: selectedSummary,
                            selectedMemberIds: _selectedMemberIds,
                            onToggleMember: _toggleMember,
                            onAddInvitees: _addInviteesFromText,
                            onAddInlineInvitee: _addInviteeFromInline,
                            onEditInvitee: _editInviteeName,
                            onRemoveInvitee: (invitee) {
                              setState(() => _invitees.remove(invitee));
                            },
                            onCopyInlineInvitee: _copyCurrentInviteeLine,
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s20),
                        SizedBox(
                          width: 360,
                          child: _ReviewPane(
                            startNow: _startNow,
                            hostOnly: _hostOnly,
                            includeAllMembers: _includeAllMembers,
                            selectedMembers: selectedMembers,
                            invitees: _invitees,
                            scheduledAt: _scheduledAt,
                            durationMinutes: _durationMinutes,
                            meetingTitle: _titleCtrl.text.trim(),
                            institutionName: institutionAsync?.maybeWhen(
                                  data: (institution) => institution.name,
                                  orElse: () => 'Owning institution',
                                ) ??
                                'Owning institution',
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CreationForm(
                          titleCtrl: _titleCtrl,
                          agendaCtrl: _agendaCtrl,
                          durationMinutes: _durationMinutes,
                          startNow: _startNow,
                          hostOnly: _hostOnly,
                          includeAllMembers: _includeAllMembers,
                          scheduledLabel: dateLabel,
                          onPickDateTime: _pickDateTime,
                          onDurationChanged: (value) =>
                              setState(() => _durationMinutes = value),
                          onStartNowChanged: (value) =>
                              setState(() => _startNow = value),
                          onHostOnlyChanged: (value) =>
                              setState(() => _hostOnly = value),
                          onAllMembersChanged: (value) =>
                              setState(() => _includeAllMembers = value),
                          institutionMode: _isInstitutionMode,
                          bookingIdentity: bookingIdentity.maybeWhen(
                            data: (value) => value,
                            orElse: () => null,
                          ),
                          bookingProfiles: bookingProfiles.maybeWhen(
                            data: (value) => value,
                            orElse: () => const [],
                          ),
                          membersAsync: membersAsync,
                          memberSearchCtrl: _memberSearchCtrl,
                          inviteCtrl: _inviteCtrl,
                          inviteNameCtrl: _inviteNameCtrl,
                          inviteEmailCtrl: _inviteEmailCtrl,
                          invitees: _invitees,
                          selectedSummary: selectedSummary,
                          selectedMemberIds: _selectedMemberIds,
                          onToggleMember: _toggleMember,
                          onAddInvitees: _addInviteesFromText,
                          onAddInlineInvitee: _addInviteeFromInline,
                          onEditInvitee: _editInviteeName,
                          onRemoveInvitee: (invitee) {
                            setState(() => _invitees.remove(invitee));
                          },
                          onCopyInlineInvitee: _copyCurrentInviteeLine,
                        ),
                        const SizedBox(height: AuraSpace.s20),
                        _ReviewPane(
                          startNow: _startNow,
                          hostOnly: _hostOnly,
                          includeAllMembers: _includeAllMembers,
                          selectedMembers: selectedMembers,
                          invitees: _invitees,
                          scheduledAt: _scheduledAt,
                          durationMinutes: _durationMinutes,
                          meetingTitle: _titleCtrl.text.trim(),
                          institutionName: institutionAsync?.maybeWhen(
                                data: (institution) => institution.name,
                                orElse: () => 'Owning institution',
                              ) ??
                              'Owning institution',
                        ),
                      ],
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
                        _startNow ? 'Start instant meeting' : 'Create meeting',
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
    );
  }
}

class _CreationForm extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController agendaCtrl;
  final int durationMinutes;
  final bool startNow;
  final bool hostOnly;
  final bool includeAllMembers;
  final String scheduledLabel;
  final VoidCallback onPickDateTime;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<bool> onStartNowChanged;
  final ValueChanged<bool> onHostOnlyChanged;
  final ValueChanged<bool> onAllMembersChanged;
  final bool institutionMode;
  final MeetingIdentityRef? bookingIdentity;
  final List<AvailabilityProfile> bookingProfiles;
  final AsyncValue<_InstitutionMembersData>? membersAsync;
  final TextEditingController memberSearchCtrl;
  final TextEditingController inviteCtrl;
  final TextEditingController inviteNameCtrl;
  final TextEditingController inviteEmailCtrl;
  final List<_DraftInvitee> invitees;
  final String selectedSummary;
  final Set<String> selectedMemberIds;
  final ValueChanged<String> onToggleMember;
  final VoidCallback onAddInvitees;
  final VoidCallback onAddInlineInvitee;
  final ValueChanged<_DraftInvitee> onEditInvitee;
  final ValueChanged<_DraftInvitee> onRemoveInvitee;
  final VoidCallback onCopyInlineInvitee;

  const _CreationForm({
    required this.titleCtrl,
    required this.agendaCtrl,
    required this.durationMinutes,
    required this.startNow,
    required this.hostOnly,
    required this.includeAllMembers,
    required this.scheduledLabel,
    required this.onPickDateTime,
    required this.onDurationChanged,
    required this.onStartNowChanged,
    required this.onHostOnlyChanged,
    required this.onAllMembersChanged,
    required this.institutionMode,
    required this.bookingIdentity,
    required this.bookingProfiles,
    required this.membersAsync,
    required this.memberSearchCtrl,
    required this.inviteCtrl,
    required this.inviteNameCtrl,
    required this.inviteEmailCtrl,
    required this.invitees,
    required this.selectedSummary,
    required this.selectedMemberIds,
    required this.onToggleMember,
    required this.onAddInvitees,
    required this.onAddInlineInvitee,
    required this.onEditInvitee,
    required this.onRemoveInvitee,
    required this.onCopyInlineInvitee,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSelectAll = membersAsync?.maybeWhen(
          data: (data) => {'OWNER', 'ADMIN', 'PLATFORM_ADMIN'}
              .contains(data.callerRole.toUpperCase()),
          orElse: () => false,
        ) ??
        false;
    final members = membersAsync?.maybeWhen(
          data: (data) => data.members,
          orElse: () => const <_InstitutionMember>[],
        ) ??
        const <_InstitutionMember>[];
    final query = memberSearchCtrl.text.trim().toLowerCase();
    final filteredMembers = members.where((member) {
      if (query.isEmpty) return true;
      return member.displayLabel.toLowerCase().contains(query) ||
          member.title.toLowerCase().contains(query) ||
          member.role.toLowerCase().contains(query);
    }).toList(growable: false);
    final currentBookingProfile = _pickBookingProfile(
      bookingProfiles,
      bookingIdentity?.auraUserId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Details',
          child: AuraCard(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: Column(
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
                  controller: agendaCtrl,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Agenda or description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
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
                  selected: {startNow},
                  onSelectionChanged: (values) =>
                      onStartNowChanged(values.first),
                ),
                if (!startNow) ...[
                  const SizedBox(height: AuraSpace.s12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: Text(scheduledLabel),
                    onPressed: onPickDateTime,
                  ),
                ],
                const SizedBox(height: AuraSpace.s12),
                DropdownButtonFormField<int>(
                  initialValue: durationMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(),
                  ),
                  items: _CreateMeetingScreenState._durations
                      .map(
                        (duration) => DropdownMenuItem(
                          value: duration,
                          child: Text(_durationLabel(duration)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onDurationChanged(value);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s18),
        _Section(
          title: 'Participants',
          child: AuraCard(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (institutionMode) ...[
                  if (canSelectAll)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includeAllMembers,
                      title: const Text('All active members'),
                      subtitle: const Text(
                        'Creates the meeting for every active eligible member.',
                      ),
                      onChanged: onAllMembersChanged,
                    ),
                  if (!includeAllMembers && membersAsync != null) ...[
                    TextField(
                      controller: memberSearchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search members',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    Wrap(
                      spacing: AuraSpace.s8,
                      runSpacing: AuraSpace.s8,
                      children: [
                        for (final member in members)
                          if (selectedMemberIds.contains(member.userId))
                            _Chip(
                              label: member.displayLabel,
                              icon: Icons.check_circle_rounded,
                              onRemove: () => onToggleMember(member.userId),
                            ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    SizedBox(
                      height: 220,
                      child: membersAsync!.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => const Center(
                          child: Text('Could not load members'),
                        ),
                        data: (_) => ListView.separated(
                          itemCount: filteredMembers.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final member = filteredMembers[index];
                            final selected =
                                selectedMemberIds.contains(member.userId);
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: selected,
                              onChanged: (_) => onToggleMember(member.userId),
                              title: Text(member.displayLabel),
                              subtitle: Text(
                                [
                                  if (member.title.isNotEmpty) member.title,
                                  if (member.role.isNotEmpty) member.role,
                                ].join(' · '),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  const Text(
                    'Open from an institution meeting to select internal members.',
                  ),
                ],
                const SizedBox(height: AuraSpace.s12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: hostOnly,
                  title: const Text('Host only'),
                  subtitle: const Text(
                    'Use only when no one else should be included.',
                  ),
                  onChanged: onHostOnlyChanged,
                ),
                if (selectedSummary.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    selectedSummary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s18),
        _Section(
          title: 'External invitees',
          child: AuraCard(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: inviteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Name <email@example.com>, Another <email@example.com>',
                    border: OutlineInputBorder(),
                    helperText: 'Press Add invitees after pasting one or more entries.',
                  ),
                ),
                const SizedBox(height: AuraSpace.s10),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Add invitees'),
                      onPressed: onAddInvitees,
                    ),
                    const SizedBox(width: AuraSpace.s8),
                    TextButton.icon(
                      icon: const Icon(Icons.content_copy_rounded),
                      label: const Text('Copy name/email'),
                      onPressed: onCopyInlineInvitee,
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: inviteNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Invitee name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    Expanded(
                      child: TextField(
                        controller: inviteEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Invitee email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    FilledButton(
                      onPressed: onAddInlineInvitee,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                if (invitees.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      for (final invitee in invitees)
                        _Chip(
                          label: invitee.displayLabel,
                          icon: Icons.mail_outline_rounded,
                          warning: invitee.name.trim().isEmpty,
                          onEdit: () => onEditInvitee(invitee),
                          onRemove: () => onRemoveInvitee(invitee),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s18),
        _Section(
          title: 'Booking page',
          child: AuraCard(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: currentBookingProfile == null
                ? const Text(
                    'Your booking page is not enabled yet.',
                  )
                : _BookingSummary(profile: currentBookingProfile),
          ),
        ),
      ],
    );
  }
}

class _ReviewPane extends StatelessWidget {
  final bool startNow;
  final bool hostOnly;
  final bool includeAllMembers;
  final List<_InstitutionMember> selectedMembers;
  final List<_DraftInvitee> invitees;
  final DateTime? scheduledAt;
  final int durationMinutes;
  final String meetingTitle;
  final String institutionName;

  const _ReviewPane({
    required this.startNow,
    required this.hostOnly,
    required this.includeAllMembers,
    required this.selectedMembers,
    required this.invitees,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.meetingTitle,
    required this.institutionName,
  });

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      institutionName,
      if (hostOnly) 'Host only',
      if (includeAllMembers) 'All active members',
      if (selectedMembers.isNotEmpty)
        selectedMembers.map((m) => m.displayLabel).join(', '),
      if (invitees.isNotEmpty)
        invitees.map((i) => i.displayLabel).join(', '),
      if (startNow)
        'Starts now'
      else if (scheduledAt != null)
        'Starts ${DateFormat('MMM d, yyyy h:mm a').format(scheduledAt!)}',
      'Duration $durationMinutes min',
      if (meetingTitle.isNotEmpty) meetingTitle,
    ];

    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AuraSpace.s10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingSummary extends StatelessWidget {
  final AvailabilityProfile profile;

  const _BookingSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    final publicUrl = '${AppConfig.publicWebUrl}${profile.publicUrl}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your booking page',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(
          publicUrl,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AuraSpace.s12),
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy link'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: publicUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking link copied')),
                );
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open page'),
              onPressed: () => launchUrl(
                Uri.parse(publicUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: publicUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking link copied for sharing')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool warning;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;

  const _Chip({
    required this.label,
    required this.icon,
    this.warning = false,
    this.onRemove,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = warning
        ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
        : const Color(0xFF6C63FF).withValues(alpha: 0.12);
    final fg = warning ? const Color(0xFFF59E0B) : const Color(0xFF8B85FF);

    return InputChip(
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(label),
      backgroundColor: bg,
      onDeleted: onRemove,
      deleteIcon: onEdit != null
          ? IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              color: fg,
              onPressed: onEdit,
            )
          : null,
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AuraSpace.s10),
        child,
      ],
    );
  }
}

class _InstitutionMembersData {
  final String callerRole;
  final List<_InstitutionMember> members;

  const _InstitutionMembersData({
    required this.callerRole,
    required this.members,
  });
}

class _InstitutionMember {
  final String userId;
  final String displayName;
  final String handle;
  final String title;
  final String role;
  final bool canSpeakOfficially;

  const _InstitutionMember({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.title,
    required this.role,
    required this.canSpeakOfficially,
  });

  String get displayLabel =>
      displayName.isNotEmpty ? displayName : handle.isNotEmpty ? '@$handle' : userId;
}

class _DraftInvitee {
  String name;
  final String email;

  _DraftInvitee({required this.name, required this.email});

  String get displayLabel =>
      name.trim().isEmpty ? email : '$name <$email>';
}

class _ParsedInvitee {
  final String name;
  final String email;

  const _ParsedInvitee({required this.name, required this.email});
}

AvailabilityProfile? _pickBookingProfile(
  List<AvailabilityProfile> profiles,
  String? currentUserId,
) {
  if (profiles.isEmpty) return null;
  final normalized = (currentUserId ?? '').trim();
  if (normalized.isNotEmpty) {
    for (final profile in profiles) {
      if (profile.assignedHost?.id == normalized || profile.owner?.id == normalized) {
        return profile;
      }
    }
  }
  for (final profile in profiles) {
    if (profile.isActive) return profile;
  }
  return profiles.first;
}

String _durationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
}
