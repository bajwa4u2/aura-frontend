import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/server_refusal.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../kind/kind_composition.dart';
import '../workspace/workspace_page.dart';
import 'engagement_models.dart';
import 'engagement_providers.dart';
import 'question_record.dart';
import '../../../core/product/product_language.dart';

/// QUESTIONS: a Collection page (DD-43).
///
/// Every question and raised issue that reached this institution, by where
/// it stands. On wide screens a question opens beside the list and is
/// answered there; on narrow screens it opens as its own page.
const _tabs = <(String id, String label, String? wire)>[
  ('waiting', 'Waiting', 'PENDING'),
  ('answered', 'Answered', 'RESPONDED'),
  ('committed', 'Committed', 'COMMITTED'),
  ('resolved', 'Resolved', 'RESOLVED'),
  ('all', 'All', null),
];

class EngagementListScreen extends ConsumerStatefulWidget {
  const EngagementListScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<EngagementListScreen> createState() => _EngagementListScreenState();
}

class _EngagementListScreenState extends ConsumerState<EngagementListScreen> {
  String _tab = 'waiting';
  String? _openId;

  String? get _status => _tabs.firstWhere((t) => t.$1 == _tab).$3;

  int? _count(EngagementSummary? s, String id) {
    if (s == null) return null;
    return switch (id) {
      'waiting' => s.pending,
      'answered' => s.responded,
      'committed' => s.committed,
      'resolved' => s.resolved,
      _ => s.total,
    };
  }

  @override
  Widget build(BuildContext context) {
    final institutionId = widget.institutionId;
    final listAsync = ref.watch(engagementFilteredListProvider((institutionId, _status)));
    // Counts need analytics standing; without it the tabs simply carry none.
    final summary = ref.watch(engagementSummaryProvider(institutionId)).valueOrNull;
    final publicWord = compositionForInstitution(ref, institutionId).publicWord;
    final records = listAsync.valueOrNull ?? const <RoutedRecord>[];

    return LayoutBuilder(
      builder: (context, box) {
        final beside = WorkspacePage.opensBeside(context, box.maxWidth);
        RoutedRecord? open;
        if (beside && records.isNotEmpty) {
          open = records.where((r) => r.id == _openId).firstOrNull ?? records.first;
        }

        return WorkspacePage(
          type: WorkspacePageType.collection,
          // "Questions from residents", "from the congregation" (DD-42 phase 3).
          title: 'Questions from $publicWord',
          purpose: 'What $publicWord ask and raise on the topics you have taken on, by where each stands.',
          primary: WorkspaceAction(
            // No icon: a compact header would otherwise show a bare "+".
            label: 'Take on a topic',
            onPressed: () => context.push('/institution/$institutionId/public-engagement/participation'),
          ),
          tabs: [
            for (final t in _tabs) WorkspaceTab(id: t.$1, label: t.$2, count: _count(summary, t.$1)),
          ],
          selectedTab: _tab,
          onTab: (id) => setState(() {
            _tab = id;
            _openId = null;
          }),
          loading: listAsync.isLoading && !listAsync.hasValue,
          detail: open == null
              ? null
              : QuestionRecord(
                  key: ValueKey(open.id),
                  institutionId: institutionId,
                  recordId: open.id,
                ),
          children: [
            if (listAsync.hasError && !listAsync.hasValue)
              WorkspaceEmpty(
                icon: Icons.error_outline_rounded,
                title: 'Questions could not be loaded',
                body: ServerRefusal.of(listAsync.error!).message ?? 'Check the connection and try again.',
                action: WorkspaceAction(
                  label: ProductLabels.of(ProductAction.retry),
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.invalidate(engagementFilteredListProvider((institutionId, _status))),
                ),
              )
            else if (records.isEmpty)
              _empty(publicWord)
            else
              for (final r in records)
                _QuestionRow(
                  record: r,
                  selected: open?.id == r.id,
                  onTap: () {
                    if (beside) {
                      setState(() => _openId = r.id);
                    } else {
                      context.push('/institution/$institutionId/public-engagement/${r.id}');
                    }
                  },
                ),
          ],
        );
      },
    );
  }

  Widget _empty(String publicWord) {
    final (title, body) = switch (_tab) {
      'waiting' => ('Nothing is waiting', 'When $publicWord ask or raise an issue on a topic you have taken on, it appears here.'),
      'answered' => ('Nothing answered yet', 'Questions you have answered appear here.'),
      'committed' => ('No open commitments', 'When you commit to act on an issue, it stays here with its date until it is resolved.'),
      'resolved' => ('Nothing resolved yet', 'Issues you have resolved appear here, with what was done.'),
      _ => ('No questions yet', 'When someone asks a question or raises an issue on a topic this institution has taken on, it appears here.'),
    };
    return WorkspaceEmpty(icon: Icons.inbox_outlined, title: title, body: body);
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.record, required this.selected, required this.onTap});

  final RoutedRecord record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final who = record.authorName;
    final when = record.postCreatedAt ?? record.routedAt;
    final due = record.commitmentDueAt;
    final overdue = record.status == RoutedRecordStatus.committed && due != null && due.isBefore(DateTime.now());

    final pill = switch (record.status) {
      RoutedRecordStatus.pending => WorkspacePill(
          label: record.acknowledgedAt != null ? 'Acknowledged' : 'Waiting',
          tone: WorkspaceTone.waiting,
        ),
      RoutedRecordStatus.responded => WorkspacePill(label: engagementStatusWords(record)),
      RoutedRecordStatus.committed => due == null
          ? const WorkspacePill(label: 'Committed', tone: WorkspaceTone.waiting)
          : overdue
              ? WorkspacePill(label: 'Was due ${AuraTemporal.dueDay(due)}', tone: WorkspaceTone.problem)
              : WorkspacePill(label: 'Due ${AuraTemporal.dueDay(due)}', tone: WorkspaceTone.waiting),
      RoutedRecordStatus.resolved => const WorkspacePill(label: 'Resolved', tone: WorkspaceTone.done),
    };

    final text = (record.postText ?? '').trim();
    final kind = record.intent == RecordIntent.issue ? 'Raised issue' : 'Question';
    return WorkspaceRow(
      leading: AuraAvatar(name: who ?? '?', imageUrl: record.author.avatarUrl, size: 36),
      title: text.isEmpty ? kind : text,
      context: [
        kind,
        if (who != null) who,
        if (record.topic != null) record.topic!.label,
        if (when != null) AuraTemporal.fullShort(when),
      ].join(' · '),
      pill: pill,
      selected: selected,
      emphasis: overdue ? WorkspaceTone.problem : null,
      onTap: onTap,
    );
  }
}
