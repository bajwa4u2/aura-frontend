import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/runtime_trace.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILTER ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _Filter {
  all('All'),
  institutions('Institutions'),
  claims('Claims'),
  joins('Joins'),
  pending('Pending'),
  provisional('Provisional');

  const _Filter(this.label);
  final String label;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AdminReviewQueueScreen extends ConsumerStatefulWidget {
  const AdminReviewQueueScreen({super.key});

  @override
  ConsumerState<AdminReviewQueueScreen> createState() =>
      _AdminReviewQueueScreenState();
}

class _AdminReviewQueueScreenState
    extends ConsumerState<AdminReviewQueueScreen> {
  _Filter _activeFilter = _Filter.all;

  List<ReviewQueueItem> _applyFilter(List<ReviewQueueItem> items) {
    return switch (_activeFilter) {
      _Filter.all => items,
      _Filter.institutions =>
        items.where((i) => i.type == 'institution_create').toList(),
      _Filter.claims =>
        items.where((i) => i.type == 'institution_claim').toList(),
      _Filter.joins => items.where((i) => i.type == 'member_join').toList(),
      _Filter.pending => items.where((i) => i.status == 'pending').toList(),
      _Filter.provisional =>
        items.where((i) => i.status == 'provisional_active').toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(adminReviewQueueProvider);

    return AuraScaffold(
      title: 'Review Queue',
      showHomeAction: true,
      body: queueAsync.when(
        loading: () =>
            const Center(child: AuraLoadingState(message: 'Loading queue…')),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load queue',
              body: adminErrorMessage(e),
              action: AuraSecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(adminReviewQueueProvider),
              ),
            ),
          ),
        ),
        data: (items) {
          final filtered = _applyFilter(items);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterBar(
                active: _activeFilter,
                onSelect: (f) => setState(() => _activeFilter = f),
                counts: _buildCounts(items),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(filter: _activeFilter)
                    : _QueueList(
                        items: filtered,
                        onApprove: _handleApprove,
                        onReject: _handleReject,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<_Filter, int> _buildCounts(List<ReviewQueueItem> items) {
    return {
      _Filter.all: items.length,
      _Filter.institutions:
          items.where((i) => i.type == 'institution_create').length,
      _Filter.claims:
          items.where((i) => i.type == 'institution_claim').length,
      _Filter.joins: items.where((i) => i.type == 'member_join').length,
      _Filter.pending: items.where((i) => i.status == 'pending').length,
      _Filter.provisional:
          items.where((i) => i.status == 'provisional_active').length,
    };
  }

  Future<void> _handleApprove(ReviewQueueItem item) async {
    RuntimeTrace.emit('admin.review', 'request',
        data: {'op': 'approve', 'id': item.id, 'type': item.type});
    try {
      await ref.read(adminRepositoryProvider).approveReview(item.id);
      RuntimeTrace.emit('admin.review', 'response',
          data: {'op': 'approve', 'id': item.id});
      if (mounted) {
        ref.invalidate(adminReviewQueueProvider);
        _showSnackbar('Approved: ${item.title}', success: true);
      }
    } catch (e) {
      String? status;
      String? body;
      if (e is DioException) {
        status = e.response?.statusCode?.toString();
        body = e.response?.data?.toString();
      }
      RuntimeTrace.emit('admin.review', 'threw', data: {
        'op': 'approve',
        'id': item.id,
        'status': status,
        'body': body,
        'err': '$e',
      });
      if (mounted) _showSnackbar('Failed to approve: ${adminErrorMessage(e)}');
    }
  }

  Future<void> _handleReject(ReviewQueueItem item) async {
    RuntimeTrace.emit('admin.review', 'request',
        data: {'op': 'reject', 'id': item.id, 'type': item.type});
    try {
      await ref.read(adminRepositoryProvider).rejectReview(item.id);
      RuntimeTrace.emit('admin.review', 'response',
          data: {'op': 'reject', 'id': item.id});
      if (mounted) {
        ref.invalidate(adminReviewQueueProvider);
        _showSnackbar('Rejected: ${item.title}');
      }
    } catch (e) {
      String? status;
      String? body;
      if (e is DioException) {
        status = e.response?.statusCode?.toString();
        body = e.response?.data?.toString();
      }
      RuntimeTrace.emit('admin.review', 'threw', data: {
        'op': 'reject',
        'id': item.id,
        'status': status,
        'body': body,
        'err': '$e',
      });
      if (mounted) _showSnackbar('Failed to reject: ${adminErrorMessage(e)}');
    }
  }

  void _showSnackbar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            success ? AuraSurface.coVerdant.withValues(alpha: 0.16) : AuraSurface.coRose.withValues(alpha: 0.16),
        content: Text(
          message,
          style: AuraText.small.copyWith(
            color: success ? AuraSurface.coVerdant : AuraSurface.coRose,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.active,
    required this.onSelect,
    required this.counts,
  });

  final _Filter active;
  final ValueChanged<_Filter> onSelect;
  final Map<_Filter, int> counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      // Wrap instead of horizontal-scroll so admin review filters never
      // hide behind a silent overflow edge.
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s10,
        ),
        child: Wrap(
          spacing: AuraSpace.s6,
          runSpacing: AuraSpace.s6,
          children: _Filter.values.map((f) {
            final selected = f == active;
            final count = counts[f] ?? 0;
            return _FilterChip(
              label: f.label,
              count: count,
              selected: selected,
              onTap: () => onSelect(f),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: AuraSpace.s6,
          ),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.accentSoft : AuraSurface.elevated,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: selected
                  ? AuraSurface.accent.withValues(alpha: 0.45)
                  : AuraSurface.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AuraText.small.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AuraSurface.accentText : AuraSurface.muted,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: AuraSpace.s6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AuraSurface.accent.withValues(alpha: 0.2)
                        : AuraSurface.divider,
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                  ),
                  child: Text(
                    '$count',
                    style: AuraText.micro.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AuraSurface.accentText
                          : AuraSurface.faint,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE LIST
// ─────────────────────────────────────────────────────────────────────────────

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.items,
    required this.onApprove,
    required this.onReject,
  });

  final List<ReviewQueueItem> items;
  final Future<void> Function(ReviewQueueItem) onApprove;
  final Future<void> Function(ReviewQueueItem) onReject;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s8),
      itemBuilder: (_, i) => _QueueCard(
        item: items[i],
        onApprove: onApprove,
        onReject: onReject,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _QueueCard extends StatefulWidget {
  const _QueueCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final ReviewQueueItem item;
  final Future<void> Function(ReviewQueueItem) onApprove;
  final Future<void> Function(ReviewQueueItem) onReject;

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard> {
  bool _loading = false;

  Future<void> _approve() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onApprove(widget.item);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onReject(widget.item);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kWorkspaceWidth),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s16),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: type badge + title ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeBadge(type: item.type),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: AuraText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AuraSurface.ink,
                          ),
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: AuraText.small
                                .copyWith(color: AuraSurface.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  _StatusBadge(status: item.status),
                ],
              ),

              const SizedBox(height: AuraSpace.s12),

              // ── Row 2: verification badges + timestamp ─────────────────
              Row(
                children: [
                  _VerifBadge(
                    label: 'Email matched',
                    verified: item.emailMatched,
                  ),
                  const SizedBox(width: AuraSpace.s6),
                  _VerifBadge(
                    label: 'DNS verified',
                    verified: item.dnsVerified,
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(item.createdAt),
                    style: AuraText.micro
                        .copyWith(color: AuraSurface.faint),
                  ),
                ],
              ),

              const SizedBox(height: AuraSpace.s12),

              // ── Row 3: actions ─────────────────────────────────────────
              _buildActionArea(),
            ],
          ),
        ),
      ),
    );
  }

  /// Status-aware action area for a queue item.
  ///
  /// Founder feedback: every item in every filter showed Reject +
  /// Approve regardless of state, so an already-approved request looked
  /// identical to a still-pending one — the admin couldn't tell at a
  /// glance what was done. Render now mirrors the actual data:
  ///   * pending / provisional_active → Reject + Approve (unchanged)
  ///   * rejected                     → "Rejected" chip, no buttons
  ///   * active + member_join         → "Active member" chip + Remove
  ///                                    (the same rejectReview path —
  ///                                    just a clearer label)
  ///   * active + institution items   → "Approved · <date>" chip from
  ///                                    the existing meta.reviewedAt
  ///   * any other / unknown status   → falls through to Reject +
  ///                                    Approve so a new backend status
  ///                                    cannot strand the admin
  ///
  /// No handlers, providers, repos, wire shape or backend code change.
  /// The pending action path is byte-identical to before.
  Widget _buildActionArea() {
    if (_loading) {
      return const Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AuraSurface.accent,
          ),
        ),
      );
    }

    final item = widget.item;
    final status = item.status.toLowerCase();
    final isMember = item.type == 'member_join';
    final needsDecision =
        status == 'pending' || status == 'provisional_active';

    if (needsDecision) {
      return _buttonsRow();
    }

    if (status == 'rejected') {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _DecisionChip(
            label: 'Rejected',
            tone: _ChipTone.danger,
            icon: Icons.cancel_rounded,
          ),
        ],
      );
    }

    if (status == 'active') {
      if (isMember) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const _DecisionChip(
              label: 'Active member',
              tone: _ChipTone.good,
              icon: Icons.check_rounded,
            ),
            const SizedBox(width: AuraSpace.s8),
            AuraSecondaryButton(
              label: 'Remove',
              icon: Icons.person_remove_outlined,
              onPressed: _reject,
            ),
          ],
        );
      }
      final reviewedAt = _formatReviewedAt(item.meta['reviewedAt']);
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _DecisionChip(
            label: reviewedAt.isEmpty
                ? 'Approved'
                : 'Approved · $reviewedAt',
            tone: _ChipTone.good,
            icon: Icons.check_circle_rounded,
          ),
        ],
      );
    }

    // Unknown future status — fall back to the original Reject +
    // Approve so a new backend value cannot strand the admin without a
    // way to action the item.
    return _buttonsRow();
  }

  Widget _buttonsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AuraSecondaryButton(
          label: 'Reject',
          icon: Icons.close_rounded,
          onPressed: _reject,
        ),
        const SizedBox(width: AuraSpace.s8),
        AuraPrimaryButton(
          label: 'Approve',
          icon: Icons.check_rounded,
          onPressed: _approve,
        ),
      ],
    );
  }

  String _formatReviewedAt(dynamic raw) {
    if (raw == null) return '';
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    final dt = DateTime.tryParse(text)?.toLocal();
    if (dt == null) return '';
    return _formatDate(dt);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MICRO WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'institution_create' => ('Institution', const Color(0xFF6366F1)),
      'institution_claim' => ('Claim', const Color(0xFFF59E0B)),
      'member_join' => ('Join', const Color(0xFF10B981)),
      _ => ('Review', AuraSurface.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// Review-queue lifecycle status rendered as a canonical SubstrateChip.
/// Mapping: active → verdant; pending → sun; provisional_active → teal
/// (governance-mediated state); rejected → rose; unknown → mist.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, state) = switch (status) {
      'pending' => ('Pending', SubstrateChipState.sun),
      'provisional_active' => ('Provisional', SubstrateChipState.teal),
      'active' => ('Active', SubstrateChipState.verdant),
      'rejected' => ('Rejected', SubstrateChipState.rose),
      _ => ('Unknown', SubstrateChipState.mist),
    };
    return SubstrateChip(label: label, state: state);
  }
}

class _VerifBadge extends StatelessWidget {
  const _VerifBadge({required this.label, required this.verified});
  final String label;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: verified ? AuraSurface.coVerdant.withValues(alpha: 0.16) : AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: verified
              ? AuraSurface.coVerdant.withValues(alpha: 0.4)
              : AuraSurface.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 10,
            color: verified ? AuraSurface.coVerdant : AuraSurface.faint,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: verified ? AuraSurface.coVerdant : AuraSurface.faint,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: AuraEmptyState(
          icon: Icons.rule_folder_rounded,
          title: filter == _Filter.all
              ? 'Queue is clear'
              : 'No ${filter.label.toLowerCase()} items',
          body: filter == _Filter.all
              ? 'All onboarding events have been reviewed.'
              : 'No items match the selected filter.',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECISION CHIP — read-only "Approved" / "Rejected" / "Active member" badge
// rendered in place of action buttons once an item no longer needs an
// admin decision. Tone-based palette uses existing AuraSurface colors so
// no new design tokens are introduced; the chip is purely presentation.
// ─────────────────────────────────────────────────────────────────────────────

enum _ChipTone { good, danger, neutral }

class _DecisionChip extends StatelessWidget {
  const _DecisionChip({
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final _ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color ink;
    switch (tone) {
      case _ChipTone.good:
        bg = AuraSurface.coVerdant.withValues(alpha: 0.16);
        ink = AuraSurface.coVerdant;
        break;
      case _ChipTone.danger:
        bg = AuraSurface.coRose.withValues(alpha: 0.16);
        ink = AuraSurface.coRose;
        break;
      case _ChipTone.neutral:
        bg = AuraSurface.subtle;
        ink = AuraSurface.muted;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: ink.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: AuraSpace.s6),
          ],
          Text(
            label,
            style: AuraText.small.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
