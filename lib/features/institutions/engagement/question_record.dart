import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/authority/authority_providers.dart';
import '../../../core/authority/capability_projection.dart';
import '../../../core/errors/server_refusal.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../posts/data/continuity_providers.dart';
import '../../posts/presentation/widgets/communication_continuity_view.dart';
import '../../topics/topic.dart';
import '../desk/desk_models.dart';
import '../desk/desk_providers.dart';
import '../kind/kind_composition.dart';
import '../workspace/workspace_page.dart';
import 'engagement_models.dart';
import 'engagement_providers.dart';
import '../../../core/product/product_language.dart';
import '../../../core/navigation/navigation_authority.dart';

/// ONE QUESTION OR ISSUE: the Record page type (DD-43).
///
/// The same widget beside the Desk's queue and as its own page, so the two
/// can never drift. Top to bottom: where it stands, what they wrote, the
/// response (written in place, not in a sheet, so the queue stays in view),
/// the commitment and its date, Memory, and the history. The lens switch
/// shows the post exactly as the public sees it, using the public panel
/// itself.
class QuestionRecord extends ConsumerStatefulWidget {
  const QuestionRecord({
    super.key,
    required this.institutionId,
    required this.recordId,
    this.back,
    this.onChanged,
  });

  final String institutionId;
  final String recordId;

  /// Only when shown as its own page.
  final WorkspaceBack? back;

  /// After a response, an acknowledgement or a date change.
  final VoidCallback? onChanged;

  @override
  ConsumerState<QuestionRecord> createState() => _QuestionRecordState();
}

enum _Outcome { answerOnly, commit, resolve }

class _QuestionRecordState extends ConsumerState<QuestionRecord> {
  String _lens = 'record';
  bool _composing = false;
  bool _busy = false;
  String? _error;
  _Outcome _outcome = _Outcome.answerOnly;
  DateTime? _due;
  final _text = TextEditingController();

  @override
  void didUpdateWidget(covariant QuestionRecord old) {
    super.didUpdateWidget(old);
    if (old.recordId != widget.recordId) {
      _text.clear();
      _lens = 'record';
      _composing = false;
      _error = null;
      _outcome = _Outcome.answerOnly;
      _due = null;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  (String, String) get _key => (widget.institutionId, widget.recordId);

  void _refresh(RoutedRecord record) {
    ref.invalidate(engagementDetailProvider(_key));
    ref.invalidate(engagementListProvider(widget.institutionId));
    ref.invalidate(engagementSummaryProvider(widget.institutionId));
    ref.invalidate(institutionMemoryProvider(_key));
    ref.invalidate(deskProvider(widget.institutionId));
    if (record.postId.isNotEmpty) ref.invalidate(continuityProvider(record.postId));
    widget.onChanged?.call();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DateTime?> _pickDay(DateTime? initial) {
    final today = DateUtils.dateOnly(DateTime.now());
    return showDatePicker(
      context: context,
      initialDate: initial != null && !initial.isBefore(today) ? initial : today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Due by',
    );
  }

  Future<void> _acknowledge(RoutedRecord record) async {
    setState(() => _busy = true);
    try {
      await ref.read(dioProvider).post('/institutions/${widget.institutionId}/engagement/${record.id}/acknowledge');
      _refresh(record);
      _say('Acknowledged. They can see you have seen it.');
    } catch (e) {
      _say(ServerRefusal.of(e).message ?? 'Could not acknowledge it just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeDue(RoutedRecord record) async {
    final day = await _pickDay(record.commitmentDueAt?.toUtc());
    if (day == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(dioProvider).put(
        '/institutions/${widget.institutionId}/engagement/${record.id}/commitment-due',
        data: {'dueAt': _isoDay(day)},
      );
      _refresh(record);
      _say(record.commitmentDueAt == null
          ? 'Due date set. The public can see it.'
          : 'Due date moved. The public can see it moved.');
    } catch (e) {
      _say(ServerRefusal.of(e).message ?? 'The date could not be changed just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send(RoutedRecord record) async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write the response first.');
      return;
    }
    if (_outcome == _Outcome.commit && _due == null) {
      setState(() => _error = 'Say when this will be done: choose a due date.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(
        '/institutions/${widget.institutionId}/engagement/${record.id}/respond',
        data: {
          'text': text,
          if (_outcome == _Outcome.commit) ...{'outcome': 'COMMITMENT', 'dueAt': _isoDay(_due!)},
          if (_outcome == _Outcome.resolve) 'outcome': 'RESOLVED',
        },
      );
      _text.clear();
      setState(() {
        _composing = false;
        _outcome = _Outcome.answerOnly;
        _due = null;
      });
      _refresh(record);
      _say('Your response is on their post, and they have been told.');
    } catch (e) {
      setState(() => _error = ServerRefusal.of(e).message ?? 'Your response could not be sent. Nothing was published.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(engagementDetailProvider(_key));
    return async.when(
      loading: () => _frame(
        header: WorkspaceHeader(title: 'Question', back: widget.back),
        children: const [WorkspaceLoading(type: WorkspacePageType.record, rows: 2)],
      ),
      error: (e, _) => _frame(
        header: WorkspaceHeader(title: 'Question', back: widget.back),
        children: [
          WorkspaceEmpty(
            icon: Icons.error_outline_rounded,
            title: 'This question could not be opened',
            body: ServerRefusal.of(e).message ?? 'Check the connection and try again.',
            action: WorkspaceAction(
              label: ProductLabels.of(ProductAction.retry),
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(engagementDetailProvider(_key)),
            ),
          ),
        ],
      ),
      data: _record,
    );
  }

  Widget _frame({required Widget header, required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, box) {
        final gutter = WorkspaceLayout.gutter(box.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, AuraSpace.s24, gutter, AuraSpace.s32),
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: WorkspaceLayout.detail),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, const SizedBox(height: AuraSpace.s16), ...children],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _record(RoutedRecord record) {
    final projection = ref.watch(capabilityProjectionForProvider(widget.institutionId));
    bool may(ConsequentialAct act) => projection.presentationFor(act) == ControlPresentation.available;
    final canRespond = may(ConsequentialAct.authorOfficialContent);
    final canSettle = may(ConsequentialAct.publishInstitutionPost);

    final isIssue = record.intent == RecordIntent.issue;
    final who = record.authorName ?? 'someone';
    final title = isIssue ? 'Issue raised by $who' : 'Question from $who';
    final reached = record.routedAt != null ? ' · reached you ${AuraTemporal.fullShort(record.routedAt!)}' : '';
    final canAnswer = canRespond && record.status != RoutedRecordStatus.resolved;
    final canAcknowledge =
        canRespond && isIssue && record.status == RoutedRecordStatus.pending && record.acknowledgedAt == null;
    final committed = record.status == RoutedRecordStatus.committed;

    final header = _RecordHeader(
      title: title,
      purpose: '${engagementStatusWords(record)}$reached',
      back: widget.back,
      primary: canAnswer && !_composing
          ? WorkspaceAction(
              label: record.status == RoutedRecordStatus.pending ? 'Respond' : 'Respond again',
              icon: Icons.reply_rounded,
              onPressed: () => setState(() {
                _composing = true;
                _lens = 'record';
              }),
            )
          : null,
      more: [
        if (canAcknowledge)
          WorkspaceAction(
            label: 'Acknowledge',
            icon: Icons.visibility_outlined,
            onPressed: _busy ? null : () => _acknowledge(record),
          ),
        if (committed && canSettle)
          WorkspaceAction(
            label: record.commitmentDueAt == null ? 'Set the due date' : 'Move the due date',
            icon: Icons.event_outlined,
            onPressed: _busy ? null : () => _changeDue(record),
          ),
        if (record.postId.isNotEmpty)
          WorkspaceAction(
            label: 'Open the post',
            icon: Icons.open_in_new_rounded,
            onPressed: () => context.push(NavigationAuthority.postRoute(record.postId)),
          ),
      ],
    );

    final lens = WorkspaceTabs(
      tabs: const [
        WorkspaceTab(id: 'record', label: 'Record'),
        WorkspaceTab(id: 'public', label: 'As the public sees it'),
      ],
      selected: _lens,
      onSelected: (id) => setState(() => _lens = id),
    );

    if (_lens == 'public') {
      return _frame(header: header, children: [
        lens,
        const SizedBox(height: AuraSpace.s20),
        _PostCard(record: record),
        const SizedBox(height: AuraSpace.s12),
        CommunicationContinuityView(
          postId: record.postId,
          postAuthorId: record.author.userId,
          postIntent: isIssue ? 'ISSUE' : 'ASK',
        ),
        const SizedBox(height: AuraSpace.s12),
        Text(
          'This is the panel under their post, as anyone sees it.',
          style: AuraText.small.copyWith(color: AuraSurface.faint),
        ),
      ]);
    }

    return _frame(header: header, children: [
      lens,
      const SizedBox(height: AuraSpace.s20),
      _PostCard(record: record),
      const SizedBox(height: AuraSpace.s24),
      if (_composing) _composer(record, canSettle: canSettle),
      if (!canRespond)
        const Padding(
          padding: EdgeInsets.only(bottom: AuraSpace.s24),
          child: Text(
            'Only someone who speaks officially for the institution can respond.',
            style: AuraText.small,
          ),
        ),
      if (committed) _commitment(record, canSettle: canSettle),
      _MemorySection(institutionId: widget.institutionId, recordId: record.id, askerName: record.authorName),
      _history(record),
    ]);
  }

  Widget _composer(RoutedRecord record, {required bool canSettle}) {
    final isIssue = record.intent == RecordIntent.issue;
    final showOutcomes = isIssue && canSettle;
    return WorkspaceSection(
      title: isIssue ? 'Your response' : 'Your answer',
      description: 'It appears on their post, in the institution’s name, and they are told.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final composition = compositionForInstitution(ref, widget.institutionId);
              if (composition.guards.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                child: KindGuardNotice(composition: composition),
              );
            },
          ),
          AuraInput(
            controller: _text,
            label: _outcome == _Outcome.resolve ? 'What was done, or why no action was needed' : 'Your response',
            maxLines: 8,
            minLines: 4,
            textInputAction: TextInputAction.newline,
          ),
          if (showOutcomes) ...[
            const SizedBox(height: AuraSpace.s16),
            const Text('This response also', style: AuraText.small),
            const SizedBox(height: AuraSpace.s8),
            WorkspaceTabs(
              tabs: [
                const WorkspaceTab(id: 'answer', label: 'Just responds'),
                if (record.status != RoutedRecordStatus.committed)
                  const WorkspaceTab(id: 'commit', label: 'Commits to act'),
                const WorkspaceTab(id: 'resolve', label: 'Marks it resolved'),
              ],
              selected: switch (_outcome) {
                _Outcome.answerOnly => 'answer',
                _Outcome.commit => 'commit',
                _Outcome.resolve => 'resolve',
              },
              onSelected: (id) => setState(() {
                _outcome = switch (id) {
                  'commit' => _Outcome.commit,
                  'resolve' => _Outcome.resolve,
                  _ => _Outcome.answerOnly,
                };
              }),
            ),
            if (_outcome == _Outcome.commit) ...[
              const SizedBox(height: AuraSpace.s12),
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 18, color: AuraSurface.muted),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(
                    child: Text(
                      _due == null ? 'Due by: choose a day' : 'Due by ${AuraTemporal.dueDay(DateTime.utc(_due!.year, _due!.month, _due!.day, 23, 59))}',
                      style: AuraText.body,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final d = await _pickDay(_due);
                      if (d != null) setState(() => _due = d);
                    },
                    style: TextButton.styleFrom(foregroundColor: AuraSurface.accentText),
                    child: Text(_due == null ? 'Choose' : 'Change'),
                  ),
                ],
              ),
              Text(
                'The public sees the date. If it has to move later, the move is shown too.',
                style: AuraText.small.copyWith(color: AuraSurface.faint),
              ),
            ],
            if (_outcome == _Outcome.resolve) ...[
              const SizedBox(height: AuraSpace.s8),
              const Text(
                'A resolution is recorded permanently. The person who raised it can reopen it within 30 days.',
                style: AuraText.small,
              ),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Text(_error!, style: AuraText.small.copyWith(color: AuraSurface.dangerInk)),
          ],
          const SizedBox(height: AuraSpace.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => setState(() => _composing = false),
                style: TextButton.styleFrom(foregroundColor: AuraSurface.muted),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AuraSpace.s8),
              WorkspacePrimaryButton(
                action: WorkspaceAction(
                  label: _busy ? 'Sending…' : 'Send response',
                  icon: Icons.send_rounded,
                  onPressed: _busy ? null : () => _send(record),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _commitment(RoutedRecord record, {required bool canSettle}) {
    final due = record.commitmentDueAt;
    final overdue = due != null && due.isBefore(DateTime.now());
    final moves = record.commitmentDueChanges.length > 1 ? record.commitmentDueChanges.sublist(1) : const [];
    return WorkspaceSection(
      title: 'The commitment',
      link: canSettle
          ? WorkspaceAction(
              label: due == null ? 'Set the date' : 'Move the date',
              onPressed: _busy ? null : () => _changeDue(record),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WorkspaceIcon(Icons.handshake_outlined, tone: overdue ? WorkspaceTone.problem : WorkspaceTone.waiting),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Text(
                  due == null
                      ? 'No date yet. A commitment says when; set one so the public can see it.'
                      : overdue
                          ? 'Was due ${AuraTemporal.dueDay(due)}. It is overdue, and the public can see that.'
                          : 'Due ${AuraTemporal.dueDay(due)}. The public can see this date.',
                  style: AuraText.body,
                ),
              ),
            ],
          ),
          for (final m in moves)
            Padding(
              padding: const EdgeInsets.only(top: AuraSpace.s8, left: 48),
              child: Text(
                'Moved${m.from != null ? ' from ${AuraTemporal.dueDay(m.from!)}' : ''}'
                '${m.to != null ? ' to ${AuraTemporal.dueDay(m.to!)}' : ''}'
                '${m.changedAt != null ? ' on ${AuraTemporal.fullShort(m.changedAt!)}' : ''}',
                style: AuraText.small,
              ),
            ),
        ],
      ),
    );
  }

  Widget _history(RoutedRecord record) {
    final isIssue = record.intent == RecordIntent.issue;
    final lines = <(IconData, String, DateTime?)>[
      if (record.routedAt != null) (Icons.call_received_rounded, 'Reached the institution', record.routedAt),
      if (record.acknowledgedAt != null) (Icons.visibility_outlined, 'Acknowledged', record.acknowledgedAt),
      if (record.status != RoutedRecordStatus.pending)
        (Icons.reply_rounded, isIssue ? 'Responded officially' : 'Answered officially', null),
      if (record.status == RoutedRecordStatus.committed || record.commitmentDueChanges.isNotEmpty)
        (
          Icons.handshake_outlined,
          'Committed to act',
          record.commitmentDueChanges.isNotEmpty ? record.commitmentDueChanges.first.changedAt : null,
        ),
      for (final r in record.resolutions) (Icons.check_circle_outline_rounded, 'Resolved: ${r.statement}', r.at),
      if (record.reopenedAt != null) (Icons.replay_rounded, 'Reopened by the person who raised it', record.reopenedAt),
    ];
    return WorkspaceSection(
      title: 'History',
      boxed: false,
      child: Column(
        children: [
          for (final (icon, text, at) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: AuraSurface.muted),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text, style: AuraText.body.copyWith(height: 1.4)),
                        if (at != null) Text(AuraTemporal.fullShort(at), style: AuraText.small),
                      ],
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

/// The record's header. Wide: actions beside the title, as on every page.
/// Narrow (a phone): the title keeps the full width and the actions sit on
/// their own line beneath it, still one gold action and one More.
class _RecordHeader extends StatelessWidget {
  const _RecordHeader({required this.title, this.purpose, this.back, this.primary, this.more = const []});

  final String title;
  final String? purpose;
  final WorkspaceBack? back;
  final WorkspaceAction? primary;
  final List<WorkspaceAction> more;

  static const double _stackBelow = 560;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= _stackBelow) {
          return WorkspaceHeader(title: title, purpose: purpose, back: back, primary: primary, more: more);
        }
        final hasActions = primary != null || more.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkspaceHeader(title: title, purpose: purpose, back: back),
            if (hasActions) ...[
              const SizedBox(height: AuraSpace.s12),
              Row(
                children: [
                  if (primary != null) WorkspacePrimaryButton(action: primary!),
                  if (primary != null && more.isNotEmpty) const SizedBox(width: AuraSpace.s8),
                  if (more.isNotEmpty) WorkspaceMoreButton(actions: more),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// What they wrote, as they wrote it.
class _PostCard extends StatelessWidget {
  const _PostCard({required this.record});

  final RoutedRecord record;

  @override
  Widget build(BuildContext context) {
    final topic = record.topic?.label;
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s18),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuraAvatar(name: record.authorName ?? '?', imageUrl: record.author.avatarUrl, size: 32),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.authorName ?? 'Someone', style: WorkspaceType.rowTitle.copyWith(fontSize: 14)),
                    Text(
                      [
                        if (record.authorHandle != null) '@${record.authorHandle}',
                        if (record.postCreatedAt != null) AuraTemporal.fullShort(record.postCreatedAt!),
                      ].join(' · '),
                      style: WorkspaceType.rowContext,
                    ),
                  ],
                ),
              ),
              if (topic != null) WorkspacePill(label: topic),
            ],
          ),
          // An empty post shows nothing: no placeholder stands in for it.
          if ((record.postText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Text(record.postText!.trim(), style: AuraText.body.copyWith(height: 1.6)),
          ],
        ],
      ),
    );
  }
}

/// MEMORY: what the institution said before, beside the answer (DD-43).
class _MemorySection extends ConsumerWidget {
  const _MemorySection({required this.institutionId, required this.recordId, this.askerName});

  final String institutionId;
  final String recordId;
  final String? askerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(institutionMemoryProvider((institutionId, recordId)));
    return WorkspaceSection(
      title: 'Memory',
      description: 'What the institution has said and promised before, so answers stay consistent.',
      child: async.when(
        loading: () => const WorkspaceLoading(rows: 2),
        error: (e, _) => const Text('Memory could not be loaded just now.', style: AuraText.small),
        data: (m) => _MemoryBody(memory: m, askerName: askerName),
      ),
    );
  }
}

class _MemoryBody extends StatelessWidget {
  const _MemoryBody({required this.memory, this.askerName});

  final InstitutionMemory memory;
  final String? askerName;

  @override
  Widget build(BuildContext context) {
    final topic = AuraTopic.fromWire(memory.topic)?.label ?? 'this topic';
    final firstName = (askerName ?? '').trim().split(' ').first;
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s8),
          child: Text(text.toUpperCase(), style: WorkspaceType.eyebrow),
        );
    Widget divider() => const Padding(
          padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
          child: Divider(height: 1, color: AuraSurface.divider),
        );
    String status(String s) => switch (s) {
          'PENDING' => 'Waiting',
          'RESPONDED' => 'Answered',
          'COMMITTED' => 'Committed',
          'RESOLVED' => 'Resolved',
          _ => s,
        };
    WorkspaceTone tone(String s) => switch (s) {
          'PENDING' => WorkspaceTone.waiting,
          'RESOLVED' => WorkspaceTone.done,
          _ => WorkspaceTone.neutral,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Said before on $topic'),
        if (memory.pastAnswers.isEmpty)
          Text('Nothing yet. This is the first on $topic.', style: AuraText.muted)
        else ...[
          Text(
            memory.answeredOnTopic == 1
                ? 'Answered once on $topic in the last twelve months.'
                : 'Answered ${memory.answeredOnTopic} times on $topic in the last twelve months.',
            style: AuraText.small,
          ),
          for (final a in memory.pastAnswers)
            Padding(
              padding: const EdgeInsets.only(top: AuraSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.question, style: AuraText.small.copyWith(color: AuraSurface.faint)),
                  const SizedBox(height: AuraSpace.s4),
                  Container(
                    padding: const EdgeInsets.only(left: AuraSpace.s12),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: AuraSurface.accent, width: 2)),
                    ),
                    child: Text(
                      a.answer ?? 'Answered, but the reply is no longer there.',
                      style: AuraText.body.copyWith(height: 1.5),
                    ),
                  ),
                  if (a.answeredAt != null) ...[
                    const SizedBox(height: AuraSpace.s4),
                    Text(AuraTemporal.fullShort(a.answeredAt!), style: AuraText.small.copyWith(color: AuraSurface.faint)),
                  ],
                ],
              ),
            ),
        ],
        divider(),
        heading(firstName.isEmpty ? 'From this person' : 'From $firstName'),
        if (memory.askerCount == 0)
          const Text('Nothing before. This is the first time they have written to you.', style: AuraText.muted)
        else ...[
          Text(
            memory.askerCount == 1 ? 'Wrote to you once before.' : 'Wrote to you ${memory.askerCount} times before.',
            style: AuraText.small,
          ),
          for (final r in memory.askerRecords)
            Padding(
              padding: const EdgeInsets.only(top: AuraSpace.s8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.question, style: AuraText.body.copyWith(height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  WorkspacePill(label: status(r.status), tone: tone(r.status)),
                ],
              ),
            ),
        ],
        divider(),
        heading('Open commitments'),
        if (memory.openCommitments == 0)
          const Text('None open. Every promise made has been kept or settled.', style: AuraText.muted)
        else ...[
          Text(
            [
              memory.openCommitments == 1 ? '1 open' : '${memory.openCommitments} open',
              if (memory.overdueCommitments > 0) '${memory.overdueCommitments} overdue',
            ].join(' · '),
            style: AuraText.small.copyWith(
              color: memory.overdueCommitments > 0 ? AuraSurface.dangerInk : AuraSurface.muted,
            ),
          ),
          for (final c in memory.commitments)
            Padding(
              padding: const EdgeInsets.only(top: AuraSpace.s8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(c.question, style: AuraText.body.copyWith(height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  WorkspacePill(
                    label: c.dueAt == null ? 'No date' : (c.overdue ? 'Was due ${AuraTemporal.dueDay(c.dueAt!)}' : 'Due ${AuraTemporal.dueDay(c.dueAt!)}'),
                    tone: c.overdue ? WorkspaceTone.problem : WorkspaceTone.waiting,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
