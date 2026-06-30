import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/meeting.dart';
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
            : meeting.participants
                  .map(
                    (p) =>
                        '${p.displayName} · ${p.attended ? 'joined' : 'not joined'}',
                  )
                  .join('\n'),
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
