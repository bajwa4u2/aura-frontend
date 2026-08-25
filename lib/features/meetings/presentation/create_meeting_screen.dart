import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/utils/local_timezone.dart';
import '../../institutions/data/institutions_repository.dart';
import '../../institutions/domain/institution.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';
import '../domain/meeting_identity.dart';
import '../../../core/identity/person_identity_model.dart';
import 'widgets/meeting_surfaces.dart';

final _institutionDetailProvider = FutureProvider.family<Institution, String>((
  ref,
  institutionId,
) {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.getById(institutionId);
});

final _institutionMembersProvider =
    FutureProvider.family<_InstitutionMembersData, String>((
      ref,
      institutionId,
    ) async {
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
          // F053/F116 (narrow Meetings authorization, founder 2026-08-19) — the
          // PERSON half of an institution member row is read canonically. `title`,
          // `role` and `canSpeakOfficially` are membership state, not identity,
          // and stay exactly where they are. No Meetings behaviour changes: this
          // replaces a duplicate interpretation, nothing else.
          final person = AuraPersonIdentity.fromJson(user);
          members.add(
            _InstitutionMember(
              userId: userId,
              displayName: person.displayName,
              handle: person.handle,
              title: (member['title'] ?? '').toString().trim(),
              role: (member['role'] ?? 'MEMBER').toString().trim(),
              canSpeakOfficially: member['canSpeakOfficially'] == true,
            ),
          );
        }
      }
      return _InstitutionMembersData(callerRole: callerRole, members: members);
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
    // NO DEFAULT TITLE. This field was pre-filled with the literal word
    // "Meeting", so anyone who did not overwrite it created a meeting called
    // Meeting - and the production database has several. A placeholder asks
    // the question instead of answering it badly.
    _titleCtrl.text = '';
    _agendaCtrl.text = '';
    // The summary names the meeting as you name it. Without this the panel
    // read "Untitled meeting" until some unrelated control forced a rebuild -
    // which was survivable only while the title arrived pre-filled.
    _titleCtrl.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
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
        participantUserIds: _includeAllMembers
            ? const []
            : _selectedMemberIds.toList(),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final selectedMembers =
        membersAsync?.maybeWhen(
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
    // "No internal members selected" was shown even while All active members
    // was ON, so the form contradicted itself: the meeting had everyone, and
    // the line underneath said nobody. Picking members individually is not
    // what is happening in that mode, so the line has nothing to report.
    final selectedSummary = _includeAllMembers || _hostOnly
        ? ''
        : selectedMembers.isEmpty
        ? 'No internal members selected'
        : selectedMembers.map((member) => member.displayLabel).join(', ');

    // R-4: the way out is the shared one. Creating a meeting is a FLOW, so
    // the governed affordance says Cancel rather than Back — a distinction
    // this screen's own arrow could not make.
    return AuraScaffold(
      title: 'Create meeting',
      body: _CreateMeetingLayout(
        isWide: isWide,
        subtitle:
            'Give the meeting a purpose, decide who is in it, and choose when.',
        form: _CreationForm(
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
          onStartNowChanged: (value) => setState(() => _startNow = value),
          onHostOnlyChanged: (value) => setState(() => _hostOnly = value),
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
        review: _ReviewPane(
          startNow: _startNow,
          hostOnly: _hostOnly,
          includeAllMembers: _includeAllMembers,
          selectedMembers: selectedMembers,
          invitees: _invitees,
          scheduledAt: _scheduledAt,
          durationMinutes: _durationMinutes,
          meetingTitle: _titleCtrl.text.trim(),
          institutionName:
              institutionAsync?.maybeWhen(
                data: (institution) => institution.name,
                orElse: () => '',
              ) ??
              '',
        ),
        submit: SizedBox(
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
                    _startNow ? Icons.video_call_rounded : Icons.add_rounded,
                  ),
            label: Text(_startNow ? 'Start instant meeting' : 'Create meeting'),
            onPressed: _saving ? null : _submit,
          ),
        ),
      ),
    );
  }
}

/// THE CREATE SURFACE'S SCROLL ARCHITECTURE.
///
/// Founder ruling (closeout correction): fix the actual scroll/layout
/// architecture; do not fake stickiness with a wrapper that does not change
/// scroll behaviour.
///
/// What was wrong: the whole screen was ONE `ListView`, and the review pane
/// was a child of it. So the panel that answers "what am I creating, for whom,
/// when" — and, more importantly, the panel that says what is still MISSING —
/// left the top of the window exactly when you scrolled to Participants, which
/// is the section that supplies the missing thing.
///
/// What this does instead: on wide layouts the form and the review rail are
/// SIBLING scrollables inside a bounded Row. The form scrolls; the rail does
/// not move with it. They are siblings, not nested, so there is no nested
/// scroll trap and no unbounded-height ambiguity — the Row's height is tight,
/// taken from the body constraints via LayoutBuilder.
///
/// The primary action lives in the rail on wide layouts, directly beneath the
/// summary: what you are about to create, and the button that creates it, in
/// one place that does not move. On narrow layouts nothing changes — one
/// column, review directly above the button, which was already correct.
class _CreateMeetingLayout extends StatelessWidget {
  final bool isWide;
  final String subtitle;
  final Widget form;
  final Widget review;
  final Widget submit;

  const _CreateMeetingLayout({
    required this.isWide,
    required this.subtitle,
    required this.form,
    required this.review,
    required this.submit,
  });

  /// The form and the rail are held together as a pair and centred as a pair,
  /// so a wide monitor does not leave a gutter between them.
  static const double _contentMaxWidth = 1180;
  static const double _railWidth = 360;

  Widget _subtitle(BuildContext context) => Text(
    subtitle,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF)),
  );

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          const SizedBox(height: AuraSpace.s6),
          _subtitle(context),
          const SizedBox(height: AuraSpace.s20),
          form,
          const SizedBox(height: AuraSpace.s20),
          review,
          const SizedBox(height: AuraSpace.s20),
          submit,
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < _contentMaxWidth
            ? constraints.maxWidth
            : _contentMaxWidth;
        return Center(
          child: SizedBox(
            // Tight on both axes. A Row of scrollables needs a bounded
            // height, and Center alone would not give it one.
            width: width,
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AuraSpace.s16,
                      AuraSpace.s16,
                      AuraSpace.s16,
                      AuraSpace.s24,
                    ),
                    children: [
                      const SizedBox(height: AuraSpace.s6),
                      _subtitle(context),
                      const SizedBox(height: AuraSpace.s20),
                      form,
                    ],
                  ),
                ),
                SizedBox(
                  width: _railWidth,
                  // Its own scrollable, so a tall summary on a short window is
                  // still reachable — but it is a SIBLING of the form's list,
                  // so it does not travel with it.
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      AuraSpace.s16,
                      AuraSpace.s16,
                      AuraSpace.s24,
                    ),
                    children: [
                      const SizedBox(height: AuraSpace.s6),
                      review,
                      const SizedBox(height: AuraSpace.s16),
                      submit,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final canSelectAll =
        membersAsync?.maybeWhen(
          data: (data) => {
            'OWNER',
            'ADMIN',
            'PLATFORM_ADMIN',
          }.contains(data.callerRole.toUpperCase()),
          orElse: () => false,
        ) ??
        false;
    final members =
        membersAsync?.maybeWhen(
          data: (data) => data.members,
          orElse: () => const <_InstitutionMember>[],
        ) ??
        const <_InstitutionMember>[];
    final query = memberSearchCtrl.text.trim().toLowerCase();
    final filteredMembers = members
        .where((member) {
          if (query.isEmpty) return true;
          return member.displayLabel.toLowerCase().contains(query) ||
              member.title.toLowerCase().contains(query) ||
              member.role.toLowerCase().contains(query);
        })
        .toList(growable: false);
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
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Meeting title',
                    // This field used to arrive pre-filled with the word
                    // "Meeting". A placeholder asks; a default answers, and it
                    // answered wrong for everyone who did not notice.
                    //
                    // The label must float from the start or Material draws it
                    // INSIDE the empty box and suppresses the hint entirely -
                    // which is what production showed on first deploy.
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'What is this meeting for?',
                    helperText: 'Everyone invited sees this first.',
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
                    // NO SCROLLABLE INSIDE THE PAGE'S SCROLLABLE.
                    //
                    // This was a fixed 220px well containing its own ListView.
                    // On a narrow window it sat across the middle of the form
                    // and swallowed the page's scroll gestures, so dragging
                    // anywhere over the member area moved nothing — the form
                    // below it, and the button that creates the meeting, were
                    // unreachable by touch. It was also a keyhole onto the
                    // list.
                    //
                    // The members now lay out inline and the page scrolls as
                    // one surface. The search field above is what narrows a
                    // long list; the count says when there is more to narrow.
                    membersAsync!.when(
                      loading: () => const MeetingSkeletonList(count: 2),
                      error: (e, _) => const MeetingError(
                        what: 'the member list',
                        technical: null,
                      ),
                      data: (_) {
                        if (filteredMembers.isEmpty) {
                          return Text(
                            memberSearchCtrl.text.trim().isEmpty
                                ? 'No members to choose from yet.'
                                : 'No members match that search.',
                            style: const TextStyle(color: AuraSurface.muted),
                          );
                        }
                        const limit = 8;
                        final shown = filteredMembers
                            .take(limit)
                            .toList(growable: false);
                        final hidden = filteredMembers.length - shown.length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var index = 0;
                              index < shown.length;
                              index++
                            ) ...[
                              if (index > 0) const Divider(height: 1),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: selectedMemberIds.contains(
                                  shown[index].userId,
                                ),
                                onChanged: (_) =>
                                    onToggleMember(shown[index].userId),
                                title: Text(shown[index].displayLabel),
                                subtitle: Text(
                                  [
                                    if (shown[index].title.isNotEmpty)
                                      shown[index].title,
                                    if (shown[index].role.isNotEmpty)
                                      shown[index].role,
                                  ].join(' · '),
                                ),
                              ),
                            ],
                            if (hidden > 0) ...[
                              const SizedBox(height: AuraSpace.s8),
                              Text(
                                '$hidden more. Search to narrow the list.',
                                style: const TextStyle(
                                  color: AuraSurface.muted,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
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
                    labelText:
                        'Name <email@example.com>, Another <email@example.com>',
                    border: OutlineInputBorder(),
                    helperText:
                        'Press Add invitees after pasting one or more entries.',
                  ),
                ),
                const SizedBox(height: AuraSpace.s10),
                // Wrap, not Row: side by side these two overflow the card on
                // a narrow window, which is how the form is most often used.
                Wrap(
                  spacing: AuraSpace.s8,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Add invitees'),
                      onPressed: onAddInvitees,
                    ),
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
        // NO BOOKING PAGE CARD HERE.
        //
        // It answered none of the questions this screen exists to answer -
        // what am I creating, for whom, when - and it sat between the last
        // field and the button that creates the meeting, so the primary
        // action of the screen was below a card about a different feature.
        // The booking page has its own place on the Meetings landing.
      ],
    );
  }
}

/// WHAT YOU ARE ABOUT TO CREATE.
///
/// Founder ruling (Create Meeting) - the panel should answer, naturally:
/// what am I creating, for whom, when, who can participate.
///
/// What this replaces: a flat list of strings, each with a green tick,
/// whether or not it represented anything being satisfied. The meeting's own
/// title was the LAST line, presented as a checklist item - so the panel
/// ticked "Meeting" at somebody who had not named their meeting yet.
///
/// It is now a summary with a shape, and - the part that matters - it shows
/// what is still MISSING as missing. Validation used to arrive only as a
/// snackbar on submit, referring to a control far below the fold.
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

  String get _who {
    if (hostOnly) return 'Just you';
    final parts = <String>[];
    if (includeAllMembers) {
      parts.add('Everyone at $institutionName');
    } else if (selectedMembers.isNotEmpty) {
      parts.add(
        selectedMembers.length == 1
            ? selectedMembers.single.displayLabel
            : '${selectedMembers.length} members',
      );
    }
    if (invitees.isNotEmpty) {
      parts.add(
        invitees.length == 1
            ? invitees.single.displayLabel
            : '${invitees.length} guests',
      );
    }
    return parts.join(' · ');
  }

  bool get _hasPeople =>
      hostOnly ||
      includeAllMembers ||
      selectedMembers.isNotEmpty ||
      invitees.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titled = meetingTitle.trim().isNotEmpty;
    final timed = startNow || scheduledAt != null;

    Widget row(IconData icon, String label, String value, {bool met = true}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AuraSpace.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              met ? icon : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: met ? AuraSurface.accentText : AuraSurface.faint,
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AuraSurface.muted,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                      color: met ? null : AuraSurface.faint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              titled ? meetingTitle.trim() : 'Untitled meeting',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: titled ? null : AuraSurface.faint,
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          row(
            Icons.schedule_rounded,
            'When',
            startNow
                ? 'Starts as soon as you create it'
                : scheduledAt != null
                ? DateFormat('EEEE d MMMM, h:mm a').format(scheduledAt!)
                : 'Pick a date and time',
            met: timed,
          ),
          row(
            Icons.timelapse_rounded,
            'How long',
            durationMinutes < 60
                ? '$durationMinutes minutes'
                : durationMinutes == 60
                ? '1 hour'
                : '${durationMinutes ~/ 60}h ${durationMinutes % 60}m',
          ),
          row(
            Icons.people_alt_rounded,
            'Who',
            _hasPeople ? _who : 'Choose who is in this meeting',
            met: _hasPeople,
          ),
          if (institutionName.trim().isNotEmpty)
            row(Icons.apartment_rounded, 'Convened by', institutionName),
        ],
      ),
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
              tooltip: 'Edit',
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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

  String get displayLabel => displayName.isNotEmpty
      ? displayName
      : handle.isNotEmpty
      ? '@$handle'
      : userId;
}

class _DraftInvitee {
  String name;
  final String email;

  _DraftInvitee({required this.name, required this.email});

  String get displayLabel => name.trim().isEmpty ? email : '$name <$email>';
}

class _ParsedInvitee {
  final String name;
  final String email;

  const _ParsedInvitee({required this.name, required this.email});
}

String _durationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
}
