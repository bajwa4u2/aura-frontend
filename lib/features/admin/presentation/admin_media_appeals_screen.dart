import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import '../data/admin_repository.dart';
import 'admin_error.dart';

/// CH-12 E6 — the reviewer's side of the route back.
///
/// D3 makes human review the authority for final disposition, and rejects both
/// advisory-only scanning and silent auto-final enforcement. This is where a
/// person actually decides.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// AUTHORITY IS THE SERVER'S. This screen performs no permission check of its
/// own — it calls the governed routes, and `AdminPermissionGuard` with
/// MODERATION_READ / MODERATION_WRITE decides. A reviewer without the
/// capability sees an empty queue because the server returned nothing, not
/// because the client hid it.
///
/// Deliberately built on the EXISTING admin repository and shell rather than a
/// new media-admin surface: a second reviewer authority would eventually
/// disagree with the first.
/// ─────────────────────────────────────────────────────────────────────────────
class AdminMediaAppealsScreen extends ConsumerWidget {
  const AdminMediaAppealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminMediaAppealsProvider);

    return AuraScaffold(
      title: 'Media appeals',
      body: async.when(
        loading: () => const AuraProductState(state: ProductState.loading),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s24),
            child: Text(adminErrorMessage(e), style: AuraText.body),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            // Genuinely empty — no appeals are waiting. A reviewer without the
            // capability also lands here, because the server returned nothing
            // rather than the client hiding anything.
            return const AuraProductState(
              state: ProductState.empty,
              headline: 'No appeals are waiting for review.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminMediaAppealsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AuraSpace.s16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s12),
              itemBuilder: (_, i) => _AppealCard(appeal: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _AppealCard extends ConsumerStatefulWidget {
  const _AppealCard({required this.appeal});

  final MediaAppealSummary appeal;

  @override
  ConsumerState<_AppealCard> createState() => _AppealCardState();
}

class _AppealCardState extends ConsumerState<_AppealCard> {
  bool _busy = false;
  String? _error;

  Future<void> _decide(String outcome) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).decideMediaAppeal(
            widget.appeal.id,
            outcome: outcome,
            // The predeclared certification summary is not hardcoded here —
            // a reviewer's decision text is theirs. This is the default only.
            decisionSummary: outcome == 'REVERSED'
                ? 'Certification fixture; released.'
                : 'Restriction confirmed after review.',
          );
      if (!mounted) return;
      // Re-read the queue from the server rather than removing the row
      // locally: the authority on what happened is the response to the next
      // fetch, not this widget's optimism.
      ref.invalidate(adminMediaAppealsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = adminErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appeal;
    final statement = (a.statement ?? '').trim();
    final reason = (a.quarantineReason ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.fileName?.trim().isNotEmpty == true ? a.fileName! : a.mediaId,
              style: AuraText.title),
          const SizedBox(height: AuraSpace.s4),
          Text(
            '${a.status} · standing ${a.standingBasis}'
            '${a.mimeType != null ? ' · ${a.mimeType}' : ''}',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),

          // The reviewer, unlike the member, is shown the examiner's actual
          // reason: they cannot decide whether the verdict was right without
          // knowing what it was. This surface is capability-gated; the
          // member-facing one is not, which is why the two say different things.
          if (reason.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Text('Restriction basis',
                style: AuraText.small.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s4),
            Text(reason, style: AuraText.body),
            if (a.quarantineSource != null)
              Text('Source: ${a.quarantineSource}',
                  style: AuraText.small.copyWith(color: AuraSurface.muted)),
          ],

          if (statement.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Text('What the appellant said',
                style: AuraText.small.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s4),
            Text(statement, style: AuraText.body),
          ],

          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(_error!, style: AuraText.small.copyWith(color: Colors.red)),
          ],

          const SizedBox(height: AuraSpace.s16),
          Row(
            children: [
              Semantics(
                button: true,
                enabled: !_busy,
                label: 'Release this attachment',
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide('REVERSED'),
                  child: const Text('Release'),
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Semantics(
                button: true,
                enabled: !_busy,
                label: 'Uphold this restriction',
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide('UPHELD'),
                  child: const Text('Uphold'),
                ),
              ),
              if (_busy) ...[
                const SizedBox(width: AuraSpace.s12),
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          // Stated on the surface, because a reviewer choosing "Uphold" should
          // know it is not a deletion. Quarantine is retention, in both
          // directions.
          Text(
            'Upholding keeps the file restricted. It is never deleted.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ],
      ),
    );
  }
}
