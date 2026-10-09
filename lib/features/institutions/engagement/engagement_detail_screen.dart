import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/authority/authority_providers.dart';
import '../../../core/authority/capability_projection.dart';
import '../../../core/errors/server_refusal.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/utils/relative_time.dart';
import 'engagement_models.dart';
import 'engagement_providers.dart';

/// ONE QUESTION OR ISSUE, AS THE INSTITUTION SEES IT (2026-10-09).
///
/// "Reply Officially" used to publish a separate institution post that was
/// never attached to the person's post: the record stayed "needs response",
/// the person was never told, and a tag failed after the post was public.
/// Responding now puts a real official reply ON their post (they are told),
/// and for a raised issue the response may also commit the institution to
/// act or record how it was resolved. Acknowledging and the record's whole
/// history live here too.
class EngagementDetailScreen extends ConsumerWidget {
  const EngagementDetailScreen({
    super.key,
    required this.institutionId,
    required this.recordId,
  });

  final String institutionId;
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(engagementDetailProvider((institutionId, recordId)));
    final projection = ref.watch(capabilityProjectionForProvider(institutionId));
    bool may(ConsequentialAct act) =>
        projection.presentationFor(act) == ControlPresentation.available;

    return AuraScaffold(
      title: 'Public question',
      showHomeAction: false,
      body: async.when(
        loading: () => const AuraProductState(state: ProductState.loading),
        error: (e, _) => AuraProductState(
          state: ProductState.retryableError,
          headline: 'This question could not be loaded',
          detail: ServerRefusal.of(e).message,
          onRecover: () => ref.invalidate(engagementDetailProvider((institutionId, recordId))),
        ),
        data: (record) => _DetailBody(
          record: record,
          institutionId: institutionId,
          canRespond: may(ConsequentialAct.authorOfficialContent),
          canSettle: may(ConsequentialAct.publishInstitutionPost),
        ),
      ),
    );
  }
}

String _modeWords(String? mode) {
  switch ((mode ?? '').toUpperCase()) {
    case 'ACCOUNTABLE':
      return 'You answer for this topic';
    case 'RESPONDING':
      return 'You respond on this topic';
    default:
      return '';
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({
    required this.record,
    required this.institutionId,
    required this.canRespond,
    required this.canSettle,
  });

  final RoutedRecord record;
  final String institutionId;
  final bool canRespond;
  final bool canSettle;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _acknowledging = false;

  void _refresh() {
    ref.invalidate(engagementDetailProvider((widget.institutionId, widget.record.id)));
    ref.invalidate(engagementListProvider(widget.institutionId));
    ref.invalidate(engagementSummaryProvider(widget.institutionId));
  }

  Future<void> _acknowledge() async {
    setState(() => _acknowledging = true);
    try {
      await ref.read(dioProvider).post(
            '/institutions/${widget.institutionId}/engagement/${widget.record.id}/acknowledge',
          );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ServerRefusal.of(e).message ?? 'Could not acknowledge it just now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  Future<void> _respond() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.page,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
      ),
      builder: (_) => _RespondSheet(
        record: widget.record,
        institutionId: widget.institutionId,
        canSettle: widget.canSettle,
      ),
    );
    if (done == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your response is on their post, and they have been told.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final isIssue = record.intent == RecordIntent.issue;
    final statusColor = switch (record.status) {
      RoutedRecordStatus.pending => AuraSurface.coSun,
      RoutedRecordStatus.resolved => AuraSurface.coVerdant,
      _ => AuraSurface.accent,
    };
    final mode = _modeWords(record.participationMode);
    final canAcknowledge = widget.canRespond &&
        isIssue &&
        record.status == RoutedRecordStatus.pending &&
        record.acknowledgedAt == null;
    final canAnswer = widget.canRespond && record.status != RoutedRecordStatus.resolved;

    return ListView(
      padding: const EdgeInsets.all(AuraSpace.s16),
      children: [
        // Where it stands.
        Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: statusColor.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Icon(
                record.status == RoutedRecordStatus.resolved
                    ? Icons.check_circle_outline_rounded
                    : record.status == RoutedRecordStatus.pending
                        ? Icons.hourglass_empty_rounded
                        : Icons.verified_outlined,
                size: 20,
                color: statusColor,
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text(
                  engagementStatusWords(record),
                  style: AuraText.body.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            if (record.intent != RecordIntent.unknown)
              _MetaChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: isIssue ? 'Raised issue' : 'Question',
              ),
            if (record.topic != null) _MetaChip(icon: Icons.label_outline_rounded, label: record.topic!.label),
            if (mode.isNotEmpty) _MetaChip(icon: Icons.domain_outlined, label: mode),
          ],
        ),
        const SizedBox(height: AuraSpace.s16),

        // What they wrote.
        if ((record.postText ?? '').trim().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AuraSpace.s14),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.postText!.trim(), style: AuraText.body.copyWith(color: AuraSurface.ink, height: 1.6)),
                if ((record.authorName ?? '').isNotEmpty || record.postCreatedAt != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Row(
                    children: [
                      if ((record.authorName ?? '').isNotEmpty) ...[
                        Text(record.authorName!, style: AuraText.small.copyWith(color: AuraSurface.muted)),
                        const SizedBox(width: AuraSpace.s8),
                      ],
                      if (record.postCreatedAt != null)
                        Text(formatRelative(record.postCreatedAt!),
                            style: AuraText.micro.copyWith(color: AuraSurface.faint)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
        ],

        // What to do.
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            if (canAnswer)
              AuraPrimaryButton(
                label: record.status == RoutedRecordStatus.pending ? 'Respond' : 'Respond again',
                icon: Icons.reply_rounded,
                onPressed: _respond,
              ),
            if (canAcknowledge)
              AuraSecondaryButton(
                label: _acknowledging ? 'Acknowledging…' : 'Acknowledge',
                onPressed: _acknowledging ? null : _acknowledge,
              ),
            if (record.postId.trim().isNotEmpty)
              AuraGhostButton(
                label: 'View their post',
                onPressed: () => context.push('/posts/${record.postId}'),
              ),
          ],
        ),
        if (!widget.canRespond)
          Padding(
            padding: const EdgeInsets.only(top: AuraSpace.s8),
            child: Text(
              'Only someone who speaks officially for the institution can respond.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
        const SizedBox(height: AuraSpace.s20),

        // What has happened so far.
        Text('History', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AuraSpace.s8),
        if (record.routedAt != null)
          _HistoryLine(icon: Icons.call_received_rounded, text: 'Reached the institution', at: record.routedAt),
        if (record.acknowledgedAt != null)
          _HistoryLine(icon: Icons.visibility_outlined, text: 'Acknowledged', at: record.acknowledgedAt),
        if (record.status != RoutedRecordStatus.pending)
          _HistoryLine(icon: Icons.reply_rounded, text: isIssue ? 'Responded officially' : 'Answered officially'),
        if (record.status == RoutedRecordStatus.committed)
          const _HistoryLine(icon: Icons.handshake_outlined, text: 'Committed to act'),
        for (final r in record.resolutions)
          _HistoryLine(icon: Icons.check_circle_outline_rounded, text: 'Resolved: ${r.statement}', at: r.at),
        if (record.reopenedAt != null)
          _HistoryLine(icon: Icons.replay_rounded, text: 'Reopened by the person who raised it', at: record.reopenedAt),
      ],
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.icon, required this.text, this.at});

  final IconData icon;
  final String text;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AuraSurface.muted),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: AuraText.body.copyWith(height: 1.4)),
                if (at != null)
                  Text(AuraTemporal.fullShort(at!), style: AuraText.small.copyWith(color: AuraSurface.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Outcome { answerOnly, commit, resolve }

/// Write the response; for a raised issue, choose what it also settles.
class _RespondSheet extends ConsumerStatefulWidget {
  const _RespondSheet({required this.record, required this.institutionId, required this.canSettle});

  final RoutedRecord record;
  final String institutionId;
  final bool canSettle;

  @override
  ConsumerState<_RespondSheet> createState() => _RespondSheetState();
}

class _RespondSheetState extends ConsumerState<_RespondSheet> {
  final _text = TextEditingController();
  _Outcome _outcome = _Outcome.answerOnly;
  bool _sending = false;
  String? _error;

  bool get _isIssue => widget.record.intent == RecordIntent.issue;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write the response first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(
        '/institutions/${widget.institutionId}/engagement/${widget.record.id}/respond',
        data: {
          'text': text,
          if (_outcome == _Outcome.commit) 'outcome': 'COMMITMENT',
          if (_outcome == _Outcome.resolve) 'outcome': 'RESOLVED',
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = ServerRefusal.of(e).message ?? 'Your response could not be sent. Nothing was published.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOutcomes = _isIssue && widget.canSettle;
    return Padding(
      padding: EdgeInsets.only(
        left: AuraSpace.s16,
        right: AuraSpace.s16,
        top: AuraSpace.s16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AuraSpace.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isIssue ? 'Respond to this issue' : 'Answer this question', style: AuraText.title.copyWith(fontSize: 18)),
          const SizedBox(height: AuraSpace.s4),
          Text(
            'Your response appears on their post, in the institution\'s name, and they are told.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _text,
            label: _outcome == _Outcome.resolve ? 'What was done, or why no action was needed' : 'Your response',
            maxLines: 6,
            minLines: 3,
            textInputAction: TextInputAction.newline,
          ),
          if (showOutcomes) ...[
            const SizedBox(height: AuraSpace.s12),
            Text('This response also…', style: AuraText.small.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s6),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                ChoiceChip(
                  label: const Text('Just responds'),
                  selected: _outcome == _Outcome.answerOnly,
                  onSelected: (_) => setState(() => _outcome = _Outcome.answerOnly),
                ),
                if (widget.record.status != RoutedRecordStatus.committed)
                  ChoiceChip(
                    label: const Text('Commits to act'),
                    selected: _outcome == _Outcome.commit,
                    onSelected: (_) => setState(() => _outcome = _Outcome.commit),
                  ),
                ChoiceChip(
                  label: const Text('Marks it resolved'),
                  selected: _outcome == _Outcome.resolve,
                  onSelected: (_) => setState(() => _outcome = _Outcome.resolve),
                ),
              ],
            ),
            if (_outcome == _Outcome.resolve)
              Padding(
                padding: const EdgeInsets.only(top: AuraSpace.s8),
                child: Text(
                  'A resolution is recorded permanently. The person who raised it can reopen it within 30 days.',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Text(_error!, style: AuraText.small.copyWith(color: AuraSurface.coRose)),
          ],
          const SizedBox(height: AuraSpace.s16),
          Align(
            alignment: Alignment.centerRight,
            child: AuraPrimaryButton(
              label: _sending ? 'Sending…' : 'Send response',
              icon: _sending ? null : Icons.send_rounded,
              onPressed: _sending ? null : _send,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s10, vertical: 5),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AuraSurface.muted),
          const SizedBox(width: 5),
          Text(label, style: AuraText.small.copyWith(color: AuraSurface.muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
