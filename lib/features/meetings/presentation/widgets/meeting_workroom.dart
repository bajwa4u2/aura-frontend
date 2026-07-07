import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/aura_space.dart';
import '../../application/meetings_provider.dart';
import '../../domain/meeting.dart';
import '../../domain/meeting_conversation_message.dart';
import 'meeting_section.dart';

/// The meeting's knowledge surface — conversation, summary narrative, and the
/// SINGLE outcome representation (MeetingOutcome rows) — embedded in the
/// Meeting Record for ended meetings.
///
/// One widget, two modes:
///  * `editable: true`  (host)   — inline outcome row editors, promote from
///    the transcript, save + share actions.
///  * `editable: false` (member) — the same record, read-only.
///
/// This absorbs the former post-meeting workspace so the record IS the
/// workspace; there is no separate "summary page vs workspace page" split.
class MeetingWorkroom extends ConsumerStatefulWidget {
  final Meeting meeting;
  final bool editable;

  const MeetingWorkroom({
    super.key,
    required this.meeting,
    required this.editable,
  });

  @override
  ConsumerState<MeetingWorkroom> createState() => _MeetingWorkroomState();
}

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
  ('DECISION', 'Decisions', 'No decisions recorded.'),
  ('COMMITMENT', 'Commitments', 'No commitments recorded.'),
  ('ACTION', 'Actions', 'No actions recorded.'),
  ('ISSUE', 'Issues', 'No issues recorded.'),
  ('FOLLOW_UP', 'Follow-ups', 'No follow-ups recorded.'),
];

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

Color _typeColorByWire(String wire) =>
    _typeColor(MeetingMessageType.parse(wire));

class _MeetingWorkroomState extends ConsumerState<MeetingWorkroom> {
  final _summaryCtrl = TextEditingController();
  String? _loadedSummaryId;
  bool _saving = false;
  bool _sharing = false;
  bool _seeded = false;
  bool _seededFromLiveNotes = false;

  final Map<String, List<_OutcomeDraft>> _drafts = {
    for (final (type, _, _) in _outcomeTypes) type: <_OutcomeDraft>[],
  };
  final Set<String> _deletedOutcomeIds = {};
  bool _outcomesLoaded = false;

  String get _meetingId => widget.meeting.id;

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

  void _loadSummary(MeetingSummary? summary) {
    if (summary == null || summary.id == _loadedSummaryId) return;
    _loadedSummaryId = summary.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _summaryCtrl.text = summary.summaryText ?? '';
      if (mounted) setState(() {});
    });
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

  // Live Notes → record bridge. Seeds ONCE, only when nothing exists yet.
  static final _prefixRe = RegExp(
    r'^(decisions?|decided|commitments?|committ?ed|commit|actions?|tasks?|to-?dos?|issues?|risks?|blockers?|follow[\s-]?ups?|next steps?)\s*[:\-–]\s*(.+)$',
    caseSensitive: false,
  );

  void _seedFromLiveNotes(MeetingSummary? summary, bool loading) {
    if (!widget.editable || _seeded || loading || summary != null) return;
    _seeded = true;
    final notes = (widget.meeting.liveNotes ?? '').trim();
    if (notes.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _importLiveNotes(notes);
        _seededFromLiveNotes = true;
      });
    });
  }

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
    if (_summaryCtrl.text.trim().isEmpty) {
      _summaryCtrl.text = summaryLines.join('\n');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(meetingsRepositoryProvider);
    try {
      await repo.saveMeetingSummary(
        _meetingId,
        summaryText:
            _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
      );
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
              _meetingId,
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
        final blanked = entry.value
            .where((d) => d.id != null && d.ctrl.text.trim().isEmpty)
            .toList();
        for (final d in blanked) {
          await repo.deleteOutcome(d.id!);
          entry.value.remove(d);
          d.dispose();
        }
      }
      ref.invalidate(meetingSummaryProvider(_meetingId));
      ref.invalidate(meetingOutcomesProvider(_meetingId));
      ref.invalidate(meetingProvider(_meetingId));
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

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(meetingsRepositoryProvider);
    try {
      var result = await repo.shareSummary(_meetingId);
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
        result = await repo.shareSummary(_meetingId, force: true);
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
        const SnackBar(content: Text('Save the summary first, then share it.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _promote(
    String messageId,
    MeetingMessageType type,
    String body,
  ) async {
    try {
      final outcomeId = await ref
          .read(meetingsRepositoryProvider)
          .promoteConversationMessage(_meetingId, messageId, type: type.wire);
      ref.invalidate(meetingConversationProvider(_meetingId));
      ref.invalidate(meetingOutcomesProvider(_meetingId));
      if (!mounted) return;
      if (outcomeId != null && body.trim().isNotEmpty) {
        setState(() {
          final list = _drafts[type.wire];
          if (list != null && !list.any((d) => d.id == outcomeId)) {
            list.add(
              _OutcomeDraft(id: outcomeId, text: body.trim(), promoted: true),
            );
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Promoted to ${type.label}')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not promote message')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(meetingSummaryProvider(_meetingId));
    final summary = summaryAsync.valueOrNull ?? widget.meeting.summary;
    _loadSummary(summary);
    final outcomesAsync = ref.watch(meetingOutcomesProvider(_meetingId));
    final outcomeRows = outcomesAsync.valueOrNull;
    if (outcomeRows != null) _loadOutcomes(outcomeRows);
    final conversation = ref
            .watch(meetingConversationProvider(_meetingId))
            .valueOrNull ??
        const <MeetingConversationMessage>[];
    _markPromoted({
      for (final m in conversation)
        if (m.isPromoted) m.promotedOutcomeId!,
    });
    if (outcomeRows != null && outcomeRows.isEmpty) {
      _seedFromLiveNotes(summary, summaryAsync.isLoading);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (conversation.isNotEmpty) ...[
          MeetingSection(
            title: 'Conversation',
            trailing: Text(
              'captured during the meeting',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF8A94A6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final msg in conversation)
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
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
                            style: theme.textTheme.bodyMedium?.copyWith(
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
                        else if (widget.editable)
                          PopupMenuButton<MeetingMessageType>(
                            tooltip: 'Promote to outcome',
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: const Icon(
                              Icons.arrow_circle_up_rounded,
                              size: 16,
                              color: Color(0xFF6C63FF),
                            ),
                            onSelected: (t) => _promote(msg.id, t, msg.body),
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
          const SizedBox(height: AuraSpace.s16),
        ],
        MeetingSection(
          title: 'Summary',
          trailing: _seededFromLiveNotes
              ? Text(
                  'pre-filled from live notes',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFF10B981)),
                )
              : null,
          child: widget.editable
              ? TextField(
                  controller: _summaryCtrl,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText:
                        'Write the meeting summary, key outcomes, and overall outcome.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                )
              : ((summary?.summaryText ?? '').trim().isEmpty
                  ? MeetingSection.emptyLine(
                      context, 'No summary recorded yet.')
                  : SelectableText(
                      summary!.summaryText!.trim(),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(height: 1.5),
                    )),
        ),
        const SizedBox(height: AuraSpace.s16),
        MeetingSection(
          title: 'Outcomes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (type, label, emptyText) in _outcomeTypes) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _typeColorByWire(type),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        label,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (_drafts[type]!.isEmpty && !widget.editable)
                  MeetingSection.emptyLine(context, emptyText),
                for (final draft in _drafts[type]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                    child: Row(
                      children: [
                        if (draft.promoted)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Tooltip(
                              message:
                                  'Promoted from the meeting conversation',
                              child: Icon(
                                Icons.task_alt_rounded,
                                size: 16,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        Expanded(
                          child: widget.editable
                              ? TextField(
                                  controller: draft.ctrl,
                                  maxLines: null,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                  ),
                                )
                              : Text(
                                  draft.ctrl.text,
                                  style: theme.textTheme.bodyMedium,
                                ),
                        ),
                        if (widget.editable)
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: Color(0xFF6B7280)),
                            onPressed: () => setState(() {
                              if (draft.id != null) {
                                _deletedOutcomeIds.add(draft.id!);
                              }
                              _drafts[type]!.remove(draft);
                              draft.dispose();
                            }),
                          ),
                      ],
                    ),
                  ),
                if (widget.editable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                    child: TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        'Add ${label.toLowerCase().replaceAll(RegExp(r's$'), '')}',
                      ),
                      onPressed: () => setState(
                        () => _drafts[type]!.add(_OutcomeDraft(text: '')),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (widget.editable) ...[
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving…' : 'Save record'),
                onPressed: _saving ? null : _save,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  _sharing ? 'Sharing…' : 'Share with participants',
                ),
                onPressed: _sharing ? null : _share,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
