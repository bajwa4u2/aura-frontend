import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error_mapper.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// IDENTITY REVIEW — the smallest surface that lets a reviewer decide well.
///
/// It answers exactly the questions the governed lifecycle requires — what was
/// submitted, by whom, when, under what class, what evidence exists, what was
/// decided before, and what decision is authorized — and deliberately stops
/// there. This is not a compliance product: no risk scores, no fraud
/// dashboards, no bulk export. Every additional field would be another copy of
/// someone's identity on another screen.
///
/// The evidence itself is NOT displayed inline. Opening an image is a separate,
/// deliberate act that writes an audit row naming the reviewer, so a queue that
/// rendered thumbnails would turn scrolling past a submission into an
/// unrecorded disclosure of it.
class IdentityReviewScreen extends ConsumerStatefulWidget {
  const IdentityReviewScreen({super.key});

  @override
  ConsumerState<IdentityReviewScreen> createState() =>
      _IdentityReviewScreenState();
}

final _queueProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await ref
      .watch(dioProvider)
      .get('/admin/identity-verification/queue');
  final data = res.data;
  if (data is Map && data['data'] is List) return data['data'] as List;
  return data is List ? data : const [];
});

class _IdentityReviewScreenState extends ConsumerState<IdentityReviewScreen> {
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(_queueProvider);

    return AuraScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Identity review', style: AuraText.title),
              const SizedBox(height: AuraSpace.s6),
              Text(
                'Oldest first. Opening a document is recorded against your account.',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s16),
              Expanded(
                child: queue.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (e, _) => Text(
                    AppErrorMapper.from(e).message,
                    style: AuraText.body,
                  ),
                  data: (rows) => rows.isEmpty
                      ? Text(
                          'Nothing waiting.',
                          style: AuraText.body.copyWith(color: AuraSurface.muted),
                        )
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AuraSpace.s10),
                          itemBuilder: (_, i) {
                            final row = Map<String, dynamic>.from(rows[i] as Map);
                            final id = (row['id'] ?? '').toString();
                            return _QueueRow(
                              row: row,
                              expanded: _openId == id,
                              onToggle: () =>
                                  setState(() => _openId = _openId == id ? null : id),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueRow extends ConsumerStatefulWidget {
  const _QueueRow({
    required this.row,
    required this.expanded,
    required this.onToggle,
  });

  final Map<String, dynamic> row;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  ConsumerState<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends ConsumerState<_QueueRow> {
  final TextEditingController _reason = TextEditingController();
  Map<String, dynamic>? _detail;
  bool _busy = false;
  String? _error;
  String? _openedUrl;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _id => (widget.row['id'] ?? '').toString();

  Future<void> _loadDetail() async {
    if (_detail != null || _busy) return;
    setState(() => _busy = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/admin/identity-verification/$_id');
      final data = res.data;
      setState(() {
        _detail = Map<String, dynamic>.from(
          (data is Map && data['data'] is Map) ? data['data'] as Map : data as Map,
        );
      });
    } catch (e) {
      setState(() => _error = AppErrorMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Open one piece of evidence. A POST, because it writes an audit row.
  Future<void> _view(String evidenceId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(dioProvider).post(
            '/admin/identity-verification/evidence/$evidenceId/view',
          );
      final data = res.data;
      final map = Map<String, dynamic>.from(
        (data is Map && data['data'] is Map) ? data['data'] as Map : data as Map,
      );
      setState(() => _openedUrl = map['url']?.toString());
    } on DioException catch (e) {
      setState(() => _error = AppErrorMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(String decision) async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'A reason is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(
        '/admin/identity-verification/$_id/decide',
        data: {'decision': decision, 'reason': reason},
      );
      if (!mounted) return;
      ref.invalidate(_queueProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppErrorMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final detail = _detail;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              widget.onToggle();
              if (!widget.expanded) _loadDetail();
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['state']} · ${row['tier']}',
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        (row['documentType'] ?? 'Document not described')
                            .toString(),
                        style: AuraText.body,
                      ),
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        'Submitted ${row['submittedAt']} · ${row['evidenceCount']} items',
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  widget.expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AuraSurface.muted,
                ),
              ],
            ),
          ),
          if (widget.expanded) ...[
            const SizedBox(height: AuraSpace.s14),
            if (_error != null) ...[
              Text(
                _error!,
                style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
              ),
              const SizedBox(height: AuraSpace.s10),
            ],
            if (_busy && detail == null)
              const CircularProgressIndicator(strokeWidth: 2)
            else if (detail != null) ...[
              Text(
                'Subject: ${(detail['subject'] as Map?)?['displayName'] ?? '—'}',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s10),
              for (final e in (detail['evidence'] as List? ?? const []))
                _EvidenceRow(
                  evidence: Map<String, dynamic>.from(e as Map),
                  busy: _busy,
                  onView: _view,
                ),
              if (_openedUrl != null) ...[
                const SizedBox(height: AuraSpace.s10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AuraRadius.r12),
                  child: Image.network(
                    _openedUrl!,
                    height: 260,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      'Could not load the image.',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ),
                ),
              ],
              if ((detail['history'] as List? ?? const []).isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s12),
                Text(
                  'Previously: ${(detail['history'] as List).map((h) => (h as Map)['state']).join(', ')}',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
              const SizedBox(height: AuraSpace.s14),
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Reason (the person is shown this)',
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: [
                  AuraPrimaryButton(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    onPressed: _busy ? null : () => _decide('APPROVED'),
                  ),
                  AuraSecondaryButton(
                    label: 'Need more',
                    onPressed: _busy ? null : () => _decide('NEEDS_MORE_INFO'),
                  ),
                  AuraSecondaryButton(
                    label: 'Reject',
                    onPressed: _busy ? null : () => _decide('REJECTED'),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                'Need more keeps the request open with unlimited retries. '
                'Reject starts a waiting period before they can try again.',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.evidence,
    required this.busy,
    required this.onView,
  });

  final Map<String, dynamic> evidence;
  final bool busy;
  final void Function(String evidenceId) onView;

  @override
  Widget build(BuildContext context) {
    final discarded = evidence['discarded'] == true;
    final id = (evidence['id'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              discarded
                  ? '${evidence['kind']} — destroyed on schedule'
                  : '${evidence['kind']}',
              style: AuraText.small.copyWith(
                color: discarded ? AuraSurface.muted : AuraSurface.ink,
              ),
            ),
          ),
          if (!discarded)
            AuraSecondaryButton(
              label: 'Open',
              onPressed: busy ? null : () => onView(id),
            ),
        ],
      ),
    );
  }
}
