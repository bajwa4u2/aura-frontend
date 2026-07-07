import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
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

// One editable outcome row in the workspace. Rows with an id exist on the
// server (MeetingOutcome); id == null is a local draft created on save.
class _OutcomeDraft {
  String? id;
  String original;
  bool promoted;
  final TextEditingController ctrl;

  _OutcomeDraft({this.id, required String text, this.promoted = false})
      : original = text,
        ctrl = TextEditingController(text: text);

  void dispose() => ctrl.dispose();
}

const _outcomeTypes = <(String, String, String)>[
  ('DECISION', 'Decisions', 'Capture the decision reached during the meeting.'),
  ('COMMITMENT', 'Commitments',
      'Track what the host, guest, or institution committed to do next.'),
  ('ACTION', 'Actions',
      'List concrete follow-up tasks that should move forward after the call.'),
  ('ISSUE', 'Issues',
      'Record any blockers, open questions, or unresolved concerns.'),
  ('FOLLOW_UP', 'Follow-ups', 'Record the next check-in, reply, or milestone.'),
];

class _PostMeetingWorkspaceScreenState
    extends ConsumerState<PostMeetingWorkspaceScreen> {
  final _summaryCtrl = TextEditingController();
  String? _loadedSummaryId;
  bool _saving = false;
  bool _sharing = false;
  // Phase 2.2 — Live Notes → Summary bridge. Seed the editor from the meeting's
  // live notes exactly once, only when no summary exists yet (never clobbers a
  // saved summary or the host's edits).
  bool _seeded = false;
  bool _seededFromLiveNotes = false;

  // One outcome representation: these drafts ARE the MeetingOutcome rows
  // (loaded once from the provider); saving diffs them back as row CRUD.
  final Map<String, List<_OutcomeDraft>> _drafts = {
    for (final (type, _, _) in _outcomeTypes) type: <_OutcomeDraft>[],
  };
  final Set<String> _deletedOutcomeIds = {};
  bool _outcomesLoaded = false;

  @override
  void dispose() {
    _summaryCtrl.dispose();
    for (final list in _drafts.values) {
      for (final d in list) {
        d.dispose();
      }
    }
    super.dispose();
  }

  void _loadOutcomes(List<MeetingOutcome> rows) {
    if (_outcomesLoaded) return;
    _outcomesLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        for (final row in rows) {
          final list = _drafts[row.type];
          if (list == null) continue;
          if (list.any((d) => d.id == row.id)) continue;
          list.add(_OutcomeDraft(id: row.id, text: row.text));
        }
      });
    });
  }

  // Promoted provenance arrives separately (outcome rows do not carry it) —
  // mark drafts whose id is a conversation promotion target.
  void _markPromoted(Set<String> promotedOutcomeIds) {
    if (promotedOutcomeIds.isEmpty) return;
    var changed = false;
    for (final list in _drafts.values) {
      for (final d in list) {
        if (d.id != null && promotedOutcomeIds.contains(d.id) && !d.promoted) {
          d.promoted = true;
          changed = true;
        }
      }
    }
    if (changed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  String get _summaryPath => widget.institutionId == null
      ? '/meetings/${widget.meetingId}/summary'
      : '/institution/${widget.institutionId}/meetings/${widget.meetingId}/summary';

  // Phase 4.5 — promote a conversation message into a MeetingOutcome, then
  // refresh the transcript (promoted marker) and outcome surfaces.
  Future<void> _promoteMessage(
    String messageId,
    MeetingMessageType type, {
    String? body,
  }) async {
    try {
      final outcomeId = await ref
          .read(meetingsRepositoryProvider)
          .promoteConversationMessage(
            widget.meetingId,
            messageId,
            type: type.wire,
          );
      ref.invalidate(meetingConversationProvider(widget.meetingId));
      ref.invalidate(meetingOutcomesProvider(widget.meetingId));
      if (mounted) {
        // One representation: the promoted row appears in its outcome section
        // immediately, marked with its conversation provenance.
        if (outcomeId != null && (body ?? '').trim().isNotEmpty) {
          setState(() {
            final list = _drafts[type.wire];
            if (list != null && !list.any((d) => d.id == outcomeId)) {
              list.add(_OutcomeDraft(
                id: outcomeId,
                text: body!.trim(),
                promoted: true,
              ));
            }
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Promoted to ${type.label}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not promote message')),
        );
      }
    }
  }

  void _loadSummary(MeetingSummary? summary) {
    if (summary == null || summary.id == _loadedSummaryId) return;
    _loadedSummaryId = summary.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Outcome sections load from MeetingOutcome rows (the single source of
      // truth) — the summary contributes only its narrative text here.
      _summaryCtrl.text = summary.summaryText ?? '';
    });
  }

  // Seed the workspace from live notes when starting a fresh summary. Runs once,
  // and only after the summary provider has resolved to "no summary" — so it can
  // never overwrite a saved summary or in-flight edits. Typed lines become
  // UNSAVED outcome drafts (created as rows on save).
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
    void addDraft(String type, String text) {
      final list = _drafts[type];
      if (list == null) return;
      if (list.any((d) => d.ctrl.text.trim() == text)) return;
      list.add(_OutcomeDraft(text: text));
    }

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
        addDraft('DECISION', rest);
      } else if (key.startsWith('commit')) {
        addDraft('COMMITMENT', rest);
      } else if (key.startsWith('action') ||
          key.startsWith('task') ||
          key.startsWith('todo') ||
          key.startsWith('to-do')) {
        addDraft('ACTION', rest);
      } else if (key.startsWith('issue') ||
          key.startsWith('risk') ||
          key.startsWith('blocker')) {
        addDraft('ISSUE', rest);
      } else {
        addDraft('FOLLOW_UP', rest);
      }
    }
    _summaryCtrl.text = summaryLines.join('\n');
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
    final repo = ref.read(meetingsRepositoryProvider);
    try {
      // Narrative first (no lists — outcome rows are the source of truth and
      // the backend mirrors the summary lists from them).
      await repo.saveMeetingSummary(
        widget.meetingId,
        summaryText:
            _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
      );

      // Outcome row diff: removed rows → delete; new rows → create; edited
      // rows → text update.
      for (final id in _deletedOutcomeIds) {
        await repo.deleteOutcome(id);
      }
      _deletedOutcomeIds.clear();
      for (final entry in _drafts.entries) {
        for (final draft in entry.value) {
          final text = draft.ctrl.text.trim();
          if (draft.id == null) {
            if (text.isEmpty) continue;
            final created = await repo.createOutcome(
              widget.meetingId,
              type: entry.key,
              text: text,
            );
            draft.id = created.id;
            draft.original = text;
          } else if (text.isNotEmpty && text != draft.original) {
            await repo.updateOutcome(draft.id!, text: text);
            draft.original = text;
          }
        }
        // Rows blanked out in place count as removals.
        final blanked = entry.value
            .where((d) => d.id != null && d.ctrl.text.trim().isEmpty)
            .toList();
        for (final d in blanked) {
          await repo.deleteOutcome(d.id!);
          entry.value.remove(d);
          d.dispose();
        }
      }

      ref.invalidate(meetingSummaryProvider(widget.meetingId));
      ref.invalidate(meetingOutcomesProvider(widget.meetingId));
      ref.invalidate(meetingProvider(widget.meetingId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Summary and outcomes saved')),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to save. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Continuity distribution — the host sends the saved summary to everyone
  // who attended. Idempotent; re-sharing after edits asks first.
  Future<void> _shareSummary() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(meetingsRepositoryProvider);
    try {
      var result = await repo.shareSummary(widget.meetingId);
      if (result.alreadyShared && mounted) {
        final resend = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Already shared'),
            content: const Text(
              'This summary was already sent to participants. Send it again with the latest edits?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Send again'),
              ),
            ],
          ),
        );
        if (resend != true) return;
        result = await repo.shareSummary(widget.meetingId, force: true);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.recipients > 0
                ? 'Summary shared with ${result.recipients} participant${result.recipients == 1 ? '' : 's'}'
                : 'Summary shared',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Save the summary first, then share it.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
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
        // Outcome rows are the editors' content; promoted provenance comes
        // from the conversation transcript.
        final outcomesAsync =
            ref.watch(meetingOutcomesProvider(widget.meetingId));
        final outcomeRows = outcomesAsync.valueOrNull;
        if (outcomeRows != null) _loadOutcomes(outcomeRows);
        final conversationRows = ref
            .watch(meetingConversationProvider(widget.meetingId))
            .valueOrNull;
        if (conversationRows != null) {
          _markPromoted({
            for (final m in conversationRows)
              if (m.isPromoted) m.promotedOutcomeId!,
          });
        }
        if (outcomeRows != null && outcomeRows.isEmpty) {
          _seedFromLiveNotes(meeting, summary, summaryAsync.isLoading);
        }
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
                      // Phase 4 — conversation reference so the host can
                      // reconcile outcomes against what was said in chat.
                      // Phase 4.5 — the host can promote messages into
                      // MeetingOutcome rows from here too.
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
                          final myId = ref
                                  .watch(authMeDataProvider)
                                  .maybeWhen(
                                    data: (me) {
                                      final u = me['user'];
                                      return (u is Map
                                              ? (u['id'] ?? '')
                                              : (me['id'] ?? ''))
                                          .toString()
                                          .trim();
                                    },
                                    orElse: () => '',
                                  );
                          final isHost = myId.isNotEmpty &&
                              myId == (meeting.host?.id ?? '');
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AuraSpace.s16,
                            ),
                            child: _ConversationReference(
                              messages: conversation,
                              onPromote: isHost
                                  ? (messageId, type) {
                                      String? body;
                                      for (final m in conversation) {
                                        if (m.id == messageId) {
                                          body = m.body;
                                          break;
                                        }
                                      }
                                      return _promoteMessage(
                                        messageId,
                                        type,
                                        body: body,
                                      );
                                    }
                                  : null,
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
                          // One outcome representation: each section edits
                          // MeetingOutcome rows directly. Rows promoted from
                          // the conversation carry a provenance check.
                          for (final (type, title, hint) in _outcomeTypes)
                            _OutcomeSection(
                              title: title,
                              hint: hint,
                              width: 510,
                              drafts: _drafts[type]!,
                              onAdd: () => setState(
                                () => _drafts[type]!.add(_OutcomeDraft(text: '')),
                              ),
                              onRemove: (draft) => setState(() {
                                if (draft.id != null) {
                                  _deletedOutcomeIds.add(draft.id!);
                                }
                                _drafts[type]!.remove(draft);
                                draft.dispose();
                              }),
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
                            label: Text(_saving ? 'Saving…' : 'Save outcomes'),
                            onPressed: _saving ? null : _saveDraft,
                          ),
                          // Continuity distribution — email the saved summary
                          // to everyone who attended.
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.send_rounded),
                            label: Text(
                              _sharing ? 'Sharing…' : 'Share with participants',
                            ),
                            onPressed: _sharing ? null : _shareSummary,
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

  /// Phase 4.5 — host-only promote action; null hides the affordance.
  final Future<void> Function(String messageId, MeetingMessageType type)?
      onPromote;

  const _ConversationReference({required this.messages, this.onPromote});

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: msg.senderName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
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
                    if (msg.isPromoted)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 2),
                        child: Tooltip(
                          message: 'Tracked as a meeting outcome',
                          child: Icon(
                            Icons.task_alt_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      )
                    else if (onPromote != null)
                      PopupMenuButton<MeetingMessageType>(
                        tooltip: 'Promote to outcome',
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: const Icon(
                          Icons.arrow_circle_up_rounded,
                          size: 16,
                          color: Color(0xFF6C63FF),
                        ),
                        onSelected: (t) => onPromote!(msg.id, t),
                        itemBuilder: (context) => [
                          for (final t in const [
                            MeetingMessageType.decision,
                            MeetingMessageType.commitment,
                            MeetingMessageType.action,
                            MeetingMessageType.issue,
                            MeetingMessageType.followUp,
                          ])
                            PopupMenuItem(
                              value: t,
                              height: 36,
                              child: Text('Promote to ${t.label}'),
                            ),
                        ],
                      ),
                  ],
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

// Structured outcome editor: one row per MeetingOutcome. This replaces the
// line-delimited textareas so the workspace, summary screen, transcript
// promotions, and institution feeds all read/write the SAME rows.
class _OutcomeSection extends StatelessWidget {
  final String title;
  final String hint;
  final double width;
  final List<_OutcomeDraft> drafts;
  final VoidCallback onAdd;
  final void Function(_OutcomeDraft draft) onRemove;

  const _OutcomeSection({
    required this.title,
    required this.hint,
    required this.width,
    required this.drafts,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AuraSpace.s12),
              if (drafts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                  child: Text(
                    hint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF6B7280)),
                  ),
                ),
              for (final draft in drafts)
                Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (draft.promoted)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Tooltip(
                            message: 'Promoted from the meeting conversation',
                            child: Icon(
                              Icons.task_alt_rounded,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: draft.ctrl,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF6B7280)),
                        onPressed: () => onRemove(draft),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Add ${title.toLowerCase().replaceAll(RegExp(r's$'), '')}'),
                onPressed: onAdd,
              ),
            ],
          ),
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
