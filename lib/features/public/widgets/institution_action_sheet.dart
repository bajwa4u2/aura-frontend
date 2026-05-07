import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../data/institution_action_repository.dart';
import '../domain/accountability_tag.dart';
import '../domain/monetization_kind.dart';

/// Public-UX Phase 4 — institution-action bottom sheet.
///
/// Shown when an admin/owner of the institution that authored a reply
/// taps the kebab on a `ReplyUnit`. Two action groups, both writing
/// directly to the new backend PATCH endpoints:
///   * **Accountability** — mark the reply as COMMITMENT / UPDATE /
///     RESOLVED, or clear the tag.
///   * **Priority** — pin the reply to the top of the thread with a
///     visible PRIORITY · PAID label, or clear the label.
///
/// Backend ownership: the institution-action repository handles the
/// HTTP; this widget just collects intent.
Future<void> showInstitutionActionSheet({
  required BuildContext context,
  required String institutionId,
  required String postId,
  required InsAccountabilityTag? currentTag,
  required MonetizationKind? currentPaidLabel,
  required void Function() onApplied,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    backgroundColor: AuraSurface.card,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
    ),
    builder: (ctx) => _InstitutionActionSheet(
      institutionId: institutionId,
      postId: postId,
      currentTag: currentTag,
      currentPaidLabel: currentPaidLabel,
      onApplied: onApplied,
    ),
  );
}

class _InstitutionActionSheet extends ConsumerStatefulWidget {
  const _InstitutionActionSheet({
    required this.institutionId,
    required this.postId,
    required this.currentTag,
    required this.currentPaidLabel,
    required this.onApplied,
  });

  final String institutionId;
  final String postId;
  final InsAccountabilityTag? currentTag;
  final MonetizationKind? currentPaidLabel;
  final void Function() onApplied;

  @override
  ConsumerState<_InstitutionActionSheet> createState() =>
      _InstitutionActionSheetState();
}

class _InstitutionActionSheetState
    extends ConsumerState<_InstitutionActionSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _setTag(InsAccountabilityTag? tag) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(institutionActionRepositoryProvider);
      await repo.setAccountability(
        institutionId: widget.institutionId,
        postId: widget.postId,
        tag: tag?.wire,
      );
      _invalidate();
      widget.onApplied();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not update accountability: $e';
        _busy = false;
      });
    }
  }

  Future<void> _setPaid(MonetizationKind? kind) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(institutionActionRepositoryProvider);
      await repo.setPaidAction(
        institutionId: widget.institutionId,
        postId: widget.postId,
        kind: _wireForPaid(kind),
      );
      _invalidate();
      widget.onApplied();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not update paid action: $e';
        _busy = false;
      });
    }
  }

  String? _wireForPaid(MonetizationKind? kind) {
    if (kind == null) return null;
    switch (kind) {
      case MonetizationKind.priorityResponse:
        return 'PRIORITY';
      case MonetizationKind.hostedSession:
        return 'HOSTED';
      case MonetizationKind.paidDistribution:
        return 'DISTRIBUTED';
      case MonetizationKind.officialResponse:
        // Free / verified — not a paid action; never sent over wire.
        return null;
    }
  }

  void _invalidate() {
    // Invalidate the institution-post detail + replies provider so
    // the UI re-fetches and renders the new label/tag immediately.
    ref.invalidate(feedItemDetailProvider(
      FeedItemDetailArgs(
        type: FeedItemType.institutionPost,
        id: widget.postId,
      ),
    ));
    ref.invalidate(feedItemRepliesProvider(
      FeedItemDetailArgs(
        type: FeedItemType.institutionPost,
        id: widget.postId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s20,
          AuraSpace.s16,
          AuraSpace.s20,
          AuraSpace.s20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AuraSurface.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s14),
            const Text(
              'Institution actions',
              style: AuraText.subtitle,
            ),
            const SizedBox(height: AuraSpace.s6),
            Text(
              'Mark this reply’s lifecycle stage and visibility. '
              'Both labels appear on the reply card for everyone.',
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                height: 1.4,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AuraSpace.s12),
              Container(
                padding: const EdgeInsets.all(AuraSpace.s10),
                decoration: BoxDecoration(
                  color: AuraSurface.dangerBg,
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  border: Border.all(
                    color: AuraSurface.dangerInk.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _error!,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.dangerInk,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.s20),

            // ── Accountability ───────────────────────────────────
            const _SectionEyebrow(label: 'ACCOUNTABILITY'),
            const SizedBox(height: AuraSpace.s8),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                for (final t in InsAccountabilityTag.values)
                  _ActionChip(
                    label: t.label,
                    selected: widget.currentTag == t,
                    onTap: _busy ? null : () => _setTag(t),
                  ),
                _ActionChip(
                  label: 'Clear',
                  selected: false,
                  onTap: (_busy || widget.currentTag == null)
                      ? null
                      : () => _setTag(null),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s20),

            // ── Priority paid action ────────────────────────────
            const _SectionEyebrow(label: 'PLACEMENT'),
            const SizedBox(height: AuraSpace.s8),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                _ActionChip(
                  label: 'Pin as Priority (paid)',
                  selected: widget.currentPaidLabel ==
                      MonetizationKind.priorityResponse,
                  onTap: _busy
                      ? null
                      : () => _setPaid(MonetizationKind.priorityResponse),
                ),
                _ActionChip(
                  label: 'Clear',
                  selected: false,
                  onTap: (_busy || widget.currentPaidLabel == null)
                      ? null
                      : () => _setPaid(null),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s14),
            Text(
              'Pricing and rules for paid placements: /aura/participation',
              style: AuraText.micro.copyWith(
                color: AuraSurface.faint,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
            Row(
              children: [
                Expanded(
                  child: AuraSecondaryButton(
                    label: 'Done',
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        fontSize: 10,
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s8,
          ),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.accentSoft : AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: selected
                  ? AuraSurface.accent.withValues(alpha: 0.4)
                  : AuraSurface.divider,
            ),
          ),
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: selected ? AuraSurface.accentText : AuraSurface.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
