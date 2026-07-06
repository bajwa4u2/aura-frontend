import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
import '../domain/meeting_conversation_message.dart';
import 'meeting_lifecycle_presenter.dart';
import 'meeting_status_chip.dart';

class PostMeetingWorkspaceScreen extends ConsumerStatefulWidget {
  final String meetingId;
  final String? institutionId;

  const PostMeetingWorkspaceScreen({
    super.key,
    required this.meetingId,
    this.institutionId,
  });

  @override
  ConsumerState<PostMeetingWorkspaceScreen> createState() =>
      _PostMeetingWorkspaceScreenState();
}

class _PostMeetingWorkspaceScreenState
    extends ConsumerState<PostMeetingWorkspaceScreen> {
  final _summaryCtrl = TextEditingController();
  final _decisionsCtrl = TextEditingController();
  final _commitmentsCtrl = TextEditingController();
  final _actionsCtrl = TextEditingController();
  final _issuesCtrl = TextEditingController();
  final _followUpsCtrl = TextEditingController();
  String? _loadedSummaryId;
  bool _saving = false;
  // Phase 2.2 — Live Notes → Summary bridge. Seed the editor from the meeting's
  // live notes exactly once, only when no summary exists yet (never clobbers a
  // saved summary or the host's edits).
  bool _seeded = false;
  bool _seededFromLiveNotes = false;

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _decisionsCtrl.dispose();
    _commitmentsCtrl.dispose();
    _actionsCtrl.dispose();
    _issuesCtrl.dispose();
    _followUpsCtrl.dispose();
    super.dispose();
  }

  String get _summaryPath => widget.institutionId == null
      ? '/meetings/${widget.meetingId}/summary'
      : '/institution/${widget.institutionId}/meetings/${widget.meetingId}/summary';

  void _loadSummary(MeetingSummary? summary) {
    if (summary == null || summary.id == _loadedSummaryId) return;
    _loadedSummaryId = summary.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _summaryCtrl.text = summary.summaryText ?? '';
      _decisionsCtrl.text = summary.decisions.join('\n');
      _commitmentsCtrl.text = summary.commitments.join('\n');
      _actionsCtrl.text = summary.actions.join('\n');
      _issuesCtrl.text = summary.issues.join('\n');
      _followUpsCtrl.text = summary.followUps.join('\n');
    });
  }

  // Seed the workspace from live notes when starting a fresh summary. Runs once,
  // and only after the summary provider has resolved to "no summary" — so it can
  // never overwrite a saved summary or in-flight edits.
  void _seedFromLiveNotes(
    Meeting meeting,
    MeetingSummary? summary,
    bool summaryLoading,
  ) {
    if (_seeded || summaryLoading || summary != null) return;
    _seeded = true;
    final notes = (meeting.liveNotes ?? '').trim();
    if (notes.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _importLiveNotes(notes);
        _seededFromLiveNotes = true;
      });
    });
  }

  // Deterministic parse: lines prefixed like "Decision:", "Commitment:",
  // "Action:/TODO:", "Issue:/Risk:", "Follow-up:/Next step:" route into their
  // lists; everything else becomes the free-text summary. Fully editable before
  // the host saves (which syncs to MeetingOutcome records on the backend).
  static final _prefixRe = RegExp(
    r'^(decisions?|decided|commitments?|committ?ed|commit|actions?|tasks?|to-?dos?|issues?|risks?|blockers?|follow[\s-]?ups?|next steps?)\s*[:\-–]\s*(.+)$',
    caseSensitive: false,
  );

  void _importLiveNotes(String notes) {
    final summaryLines = <String>[];
    final decisions = <String>[];
    final commitments = <String>[];
    final actions = <String>[];
    final issues = <String>[];
    final followUps = <String>[];
    for (final raw in notes.split(RegExp(r'\r?\n'))) {
      final line = raw.trim().replaceFirst(RegExp(r'^[-*•]\s+'), '').trim();
      if (line.isEmpty) continue;
      final m = _prefixRe.firstMatch(line);
      if (m == null) {
        summaryLines.add(line);
        continue;
      }
      final key = m.group(1)!.toLowerCase();
      final rest = m.group(2)!.trim();
      if (key.startsWith('decision') || key == 'decided') {
        decisions.add(rest);
      } else if (key.startsWith('commit')) {
        commitments.add(rest);
      } else if (key.startsWith('action') ||
          key.startsWith('task') ||
          key.startsWith('todo') ||
          key.startsWith('to-do')) {
        actions.add(rest);
      } else if (key.startsWith('issue') ||
          key.startsWith('risk') ||
          key.startsWith('blocker')) {
        issues.add(rest);
      } else {
        followUps.add(rest);
      }
    }
    _summaryCtrl.text = summaryLines.join('\n');
    if (decisions.isNotEmpty) _decisionsCtrl.text = decisions.join('\n');
    if (commitments.isNotEmpty) _commitmentsCtrl.text = commitments.join('\n');
    if (actions.isNotEmpty) _actionsCtrl.text = actions.join('\n');
    if (issues.isNotEmpty) _issuesCtrl.text = issues.join('\n');
    if (followUps.isNotEmpty) _followUpsCtrl.text = followUps.join('\n');
  }

  List<String> _splitLines(String value) {
    return value
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void _copyLink(Meeting meeting) {
    Clipboard.setData(ClipboardData(text: meeting.joinUrl));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meeting link copied')));
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(meetingsRepositoryProvider)
          .saveMeetingSummary(
            widget.meetingId,
            summaryText: _summaryCtrl.text.trim().isEmpty
                ? null
                : _summaryCtrl.text.trim(),
            decisions: _splitLines(_decisionsCtrl.text),
            commitments: _splitLines(_commitmentsCtrl.text),
            actions: _splitLines(_actionsCtrl.text),
            issues: _splitLines(_issuesCtrl.text),
            followUps: _splitLines(_followUpsCtrl.text),
          );
      ref.invalidate(meetingSummaryProvider(widget.meetingId));
      ref.invalidate(meetingProvider(widget.meetingId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Meeting summary saved')),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to save summary. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(meetingProvider(widget.meetingId));
    final summaryAsync = ref.watch(meetingSummaryProvider(widget.meetingId));

    return meetingAsync.when(
      loading: () => AuraScaffold(
        title: 'Post-meeting workspace',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Post-meeting workspace',
        body: const Center(child: Text('Unable to load post-meeting workspace.')),
      ),
      data: (meeting) {
        final summary = summaryAsync.valueOrNull ?? meeting.summary;
        _loadSummary(summary);
        _seedFromLiveNotes(meeting, summary, summaryAsync.isLoading);
        final room = meeting.room;
        final lifecycle = MeetingLifecyclePresenter.present(
          meeting,
          room: room,
          isHost: true,
        );
        final booking = meeting.booking;
        final institutionName =
            booking?.institution?.name ??
            booking?.bookingPageName ??
            meeting.host?.name ??
            'Meeting';

        return AuraScaffold(
          title: 'Post-meeting workspace',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(_summaryPath),
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
                      _WorkspaceHeader(
                        meeting: meeting,
                        lifecycle: lifecycle,
                        institutionName: institutionName,
                        onCopy: () => _copyLink(meeting),
                        onSummary: () => context.go(_summaryPath),
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      if ((meeting.liveNotes ?? '').trim().isNotEmpty) ...[
                        _LiveNotesReference(
                          notes: meeting.liveNotes!.trim(),
                          seeded: _seededFromLiveNotes,
                        ),
                        const SizedBox(height: AuraSpace.s16),
                      ],
                      // Phase 4 — read-only conversation reference so the host
                      // can reconcile outcomes against what was said in chat.
                      Consumer(
                        builder: (context, ref, _) {
                          final conversation = ref
                                  .watch(meetingConversationProvider(
                                      widget.meetingId))
                                  .valueOrNull ??
                              const <MeetingConversationMessage>[];
                          if (conversation.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AuraSpace.s16,
                            ),
                            child: _ConversationReference(
                              messages: conversation,
                            ),
                          );
                        },
                      ),
                      Wrap(
                        spacing: AuraSpace.s16,
                        runSpacing: AuraSpace.s16,
                        children: [
                          _EditorPanel(
                            title: 'Summary',
                            width: 1040,
                            controller: _summaryCtrl,
                            hint:
                                'Write the meeting summary, key outcomes, and overall outcome.',
                            maxLines: 6,
                          ),
                          _EditorPanel(
                            title: 'Decisions',
                            width: 510,
                            controller: _decisionsCtrl,
                            hint:
                                'Capture the decision reached during the meeting.',
                          ),
                          _EditorPanel(
                            title: 'Commitments',
                            width: 510,
                            controller: _commitmentsCtrl,
                            hint:
                                'Track what the host, guest, or institution committed to do next.',
                          ),
                          _EditorPanel(
                            title: 'Actions',
                            width: 510,
                            controller: _actionsCtrl,
                            hint:
                                'List concrete follow-up tasks that should move forward after the call.',
                          ),
                          _EditorPanel(
                            title: 'Issues',
                            width: 510,
                            controller: _issuesCtrl,
                            hint:
                                'Record any blockers, open questions, or unresolved concerns.',
                          ),
                          _EditorPanel(
                            title: 'Follow-ups',
                            width: 510,
                            controller: _followUpsCtrl,
                            hint:
                                'Record the next check-in, reply, or milestone.',
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      Wrap(
                        spacing: AuraSpace.s10,
                        runSpacing: AuraSpace.s10,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Save outcomes'),
                            onPressed: _saving ? null : _saveDraft,
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Back to summary'),
                            onPressed: () => context.go(_summaryPath),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.content_copy_rounded),
                            label: const Text('Copy meeting link'),
                            onPressed: () => _copyLink(meeting),
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _MemoryPanel(meeting: meeting, booking: booking),
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
}

// Phase 2.2 — read-only source panel showing the notes captured live, kept
// visible so the host can reconcile the summary against what was actually said.
class _LiveNotesReference extends StatelessWidget {
  final String notes;
  final bool seeded;

  const _LiveNotesReference({required this.notes, required this.seeded});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded,
                    size: 18, color: Color(0xFF6C63FF)),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  'Live notes',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  'captured during the meeting',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF9CA3AF)),
                ),
              ],
            ),
            if (seeded) ...[
              const SizedBox(height: AuraSpace.s8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pre-filled the summary below from these notes — review and edit before saving.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: const Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AuraSpace.s10),
            SelectableText(
              notes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFCBD5E1),
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// Phase 4 — read-only conversation reference. Typed messages (decisions,
// commitments, …) are highlighted so the host can lift them into the outcome
// editors; message promotion to first-class outcomes is a later step.
class _ConversationReference extends StatelessWidget {
  final List<MeetingConversationMessage> messages;

  const _ConversationReference({required this.messages});

  Color _typeColor(MeetingMessageType type) {
    switch (type) {
      case MeetingMessageType.decision:
        return const Color(0xFF10B981);
      case MeetingMessageType.commitment:
        return const Color(0xFFF59E0B);
      case MeetingMessageType.action:
        return const Color(0xFF38BDF8);
      case MeetingMessageType.issue:
        return const Color(0xFFF43F5E);
      case MeetingMessageType.followUp:
        return const Color(0xFF8B5CF6);
      case MeetingMessageType.chat:
      case MeetingMessageType.system:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 18, color: Color(0xFF6C63FF)),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  'Conversation',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  'captured during the meeting',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF9CA3AF)),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s10),
            for (final msg in messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SelectableText.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: msg.senderName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (msg.messageType != MeetingMessageType.chat)
                        TextSpan(
                          text: ' · ${msg.messageType.label}',
                          style: TextStyle(
                            color: _typeColor(msg.messageType),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      TextSpan(text: '  ${msg.body}'),
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFCBD5E1),
                        height: 1.4,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final Meeting meeting;
  final MeetingLifecycleViewModel lifecycle;
  final String institutionName;
  final VoidCallback onCopy;
  final VoidCallback onSummary;

  const _WorkspaceHeader({
    required this.meeting,
    required this.lifecycle,
    required this.institutionName,
    required this.onCopy,
    required this.onSummary,
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
              children: [
                MeetingStatusChip(lifecycle: lifecycle),
                const _SmallChip(
                  icon: Icons.business_rounded,
                  label: 'Institution memory',
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
            const SizedBox(height: AuraSpace.s16),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Back to summary'),
                  onPressed: onSummary,
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

class _EditorPanel extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String hint;
  final double width;
  final int maxLines;

  const _EditorPanel({
    required this.title,
    required this.controller,
    required this.hint,
    required this.width,
    this.maxLines = 5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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
              TextField(
                controller: controller,
                maxLines: maxLines,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryPanel extends StatelessWidget {
  final Meeting meeting;
  final MeetingBookingDetails? booking;

  const _MemoryPanel({required this.meeting, required this.booking});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (booking?.bookerIdentity != null)
        _MemoryRow(
          title: 'Booked by',
          body: [
            booking!.bookerIdentity!.displayName,
            if (booking!.bookerIdentity!.email.trim().isNotEmpty)
              booking!.bookerIdentity!.email.trim(),
            if (booking!.bookerIdentity!.title?.trim().isNotEmpty == true)
              booking!.bookerIdentity!.title!.trim(),
          ].join(' · '),
        ),
      _MemoryRow(
        title: 'Attendance',
        body: meeting.participants.isEmpty
            ? 'Attendance will appear once participants join.'
            : meeting.participants.map((p) {
                if (!p.attended) return '${p.displayName} · not joined';
                final dur = p.durationMinutes;
                return dur != null
                    ? '${p.displayName} · ${dur}m'
                    : '${p.displayName} · joined';
              }).join('\n'),
      ),
      if (booking?.bookerNotes?.trim().isNotEmpty == true)
        _MemoryRow(title: 'Guest note', body: booking!.bookerNotes!.trim()),
      if ((meeting.description ?? '').trim().isNotEmpty)
        _MemoryRow(
          title: 'Meeting description',
          body: meeting.description!.trim(),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meeting memory',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AuraSpace.s12),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  final String title;
  final String body;

  const _MemoryRow({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AuraSpace.s4),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFE5E7EB),
              height: 1.4,
            ),
          ),
        ],
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
