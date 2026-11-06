import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/aura_notice.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../application/meetings_provider.dart';
import '../../domain/meeting_agenda_item.dart';

/// The outcome kinds an agenda point can become, in the server's words.
const List<(String, String)> kAgendaOutcomeKinds = [
  ('DECISION', 'Decision'),
  ('COMMITMENT', 'Commitment'),
  ('ACTION', 'Action'),
  ('ISSUE', 'Issue'),
  ('FOLLOW_UP', 'Follow-up'),
];

/// AGENDA POINTS (6 Nov 2026).
///
/// The agenda was one block of free text, so nothing on it could be ticked
/// off, and nothing said in the meeting could be traced back to the point it
/// answered. Points are now an ordered list. Before and during the meeting
/// the people who run it add, reword, tick and remove them; afterwards each
/// can become an outcome (a decision, a commitment...). Everyone else reads
/// the list.
class MeetingAgendaItems extends ConsumerStatefulWidget {
  const MeetingAgendaItems({
    super.key,
    required this.meetingId,
    required this.editable,
    required this.canMakeOutcomes,
  });

  final String meetingId;

  /// Add, reword, tick and remove (host, co-host or manager, before the end).
  final bool editable;

  /// "Make it an outcome" (host, co-host or manager, once it has happened).
  final bool canMakeOutcomes;

  @override
  ConsumerState<MeetingAgendaItems> createState() => _MeetingAgendaItemsState();
}

class _MeetingAgendaItemsState extends ConsumerState<MeetingAgendaItems> {
  final _newItem = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String failure,
      {String? done}) async {
    setState(() => _busy = true);
    final notice = AuraNotice.of(context);
    try {
      await action();
      // The page may have closed while the request was out (QC 6 Nov 2026).
      if (!mounted) return;
      ref.invalidate(meetingAgendaProvider(widget.meetingId));
      if (done != null) notice.done(done);
    } catch (_) {
      if (mounted) notice.problem(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final text = _newItem.text.trim();
    if (text.isEmpty) return;
    await _run(
      () => ref
          .read(meetingsRepositoryProvider)
          .addAgendaItem(widget.meetingId, text),
      'That point was not added. Try again.',
    );
    if (mounted) _newItem.clear();
  }

  Future<void> _edit(MeetingAgendaItem item) async {
    final ctrl = TextEditingController(text: item.text);
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit agenda point'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder()),
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
    if (text == null || text.isEmpty || text == item.text || !mounted) return;
    await _run(
      () => ref
          .read(meetingsRepositoryProvider)
          .updateAgendaItem(widget.meetingId, item.id, text: text),
      'That point was not saved. Try again.',
    );
  }

  Future<void> _makeOutcome(MeetingAgendaItem item, String type, String label) =>
      _run(
        () async {
          await ref
              .read(meetingsRepositoryProvider)
              .agendaItemToOutcome(widget.meetingId, item.id, type: type);
          ref.invalidate(meetingOutcomesProvider(widget.meetingId));
          ref.invalidate(meetingProvider(widget.meetingId));
        },
        'The outcome was not recorded. Try again.',
        done: 'Recorded as a ${label.toLowerCase()}.',
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = ref.watch(meetingAgendaProvider(widget.meetingId));
    final list = items.valueOrNull ?? const <MeetingAgendaItem>[];
    final readOnly = !widget.editable && !widget.canMakeOutcomes;
    if (readOnly && list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.hasError && list.isEmpty)
          Text(
            "Couldn't load the agenda points.",
            style: theme.textTheme.bodySmall?.copyWith(color: AuraSurface.muted),
          ),
        for (final item in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                if (widget.editable)
                  Checkbox(
                    value: item.covered,
                    onChanged: _busy
                        ? null
                        : (v) => _run(
                              () => ref
                                  .read(meetingsRepositoryProvider)
                                  .updateAgendaItem(widget.meetingId, item.id,
                                      covered: v ?? false),
                              'That point was not updated. Try again.',
                            ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(AuraSpace.s10),
                    child: Icon(
                      item.covered
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: item.covered
                          ? AuraSurface.goodInk
                          : AuraSurface.faint,
                    ),
                  ),
                Expanded(
                  child: Text(
                    item.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: item.covered ? AuraSurface.muted : null,
                    ),
                  ),
                ),
                if (widget.editable) ...[
                  IconButton(
                    tooltip: 'Edit this point',
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    color: AuraSurface.muted,
                    onPressed: _busy ? null : () => _edit(item),
                  ),
                  IconButton(
                    tooltip: 'Remove this point',
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        size: 18),
                    color: AuraSurface.muted,
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => ref
                                  .read(meetingsRepositoryProvider)
                                  .removeAgendaItem(widget.meetingId, item.id),
                              'That point was not removed. Try again.',
                            ),
                  ),
                ],
                if (widget.canMakeOutcomes)
                  item.outcomeId != null
                      ? Padding(
                          padding: const EdgeInsets.only(left: AuraSpace.s8),
                          child: Text(
                            'Outcome recorded',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AuraSurface.goodInk),
                          ),
                        )
                      : PopupMenuButton<(String, String)>(
                          tooltip: 'Make it an outcome',
                          enabled: !_busy,
                          onSelected: (kind) =>
                              _makeOutcome(item, kind.$1, kind.$2),
                          itemBuilder: (_) => [
                            for (final kind in kAgendaOutcomeKinds)
                              PopupMenuItem(value: kind, child: Text(kind.$2)),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s8,
                                vertical: AuraSpace.s6),
                            child: Text(
                              'Make it an outcome',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AuraSurface.accentText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
              ],
            ),
          ),
        if (widget.editable) ...[
          if (list.isNotEmpty) const SizedBox(height: AuraSpace.s6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItem,
                  enabled: !_busy,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _add(),
                  decoration: const InputDecoration(
                    hintText: 'Add an agenda point',
                    counterText: '',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              FilledButton.tonal(
                onPressed: _busy ? null : _add,
                child: const Text('Add'),
              ),
            ],
          ),
        ],
        if (widget.canMakeOutcomes && !widget.editable && list.isEmpty)
          Text(
            'No agenda points were set for this meeting.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AuraSurface.muted),
          ),
      ],
    );
  }
}
