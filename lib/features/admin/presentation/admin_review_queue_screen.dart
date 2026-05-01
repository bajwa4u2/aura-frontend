import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
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
    try {
      await ref.read(adminRepositoryProvider).approveReview(item.id);
      if (mounted) {
        ref.invalidate(adminReviewQueueProvider);
        _showSnackbar('Approved: ${item.title}', success: true);
      }
    } catch (e) {
      if (mounted) _showSnackbar('Failed to approve: ${adminErrorMessage(e)}');
    }
  }

  Future<void> _handleReject(ReviewQueueItem item) async {
    try {
      await ref.read(adminRepositoryProvider).rejectReview(item.id);
      if (mounted) {
        ref.invalidate(adminReviewQueueProvider);
        _showSnackbar('Rejected: ${item.title}');
      }
    } catch (e) {
      if (mounted) _showSnackbar('Failed to reject: ${adminErrorMessage(e)}');
    }
  }

  void _showSnackbar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            success ? AuraSurface.goodBg : AuraSurface.dangerBg,
        content: Text(
          message,
          style: AuraText.small.copyWith(
            color: success ? AuraSurface.goodInk : AuraSurface.dangerInk,
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s10,
        ),
        child: Row(
          children: _Filter.values.map((f) {
            final selected = f == active;
            final count = counts[f] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: AuraSpace.s6),
              child: _FilterChip(
                label: f.label,
                count: count,
                selected: selected,
                onTap: () => onSelect(f),
              ),
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
        constraints: const BoxConstraints(maxWidth: 960),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AuraSurface.accent,
                      ),
                    )
                  else ...[
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'pending' => ('Pending', AuraSurface.warnBg, AuraSurface.warnInk),
      'provisional_active' => (
          'Provisional',
          const Color(0x206366F1),
          const Color(0xFF6366F1),
        ),
      'active' => ('Active', AuraSurface.goodBg, AuraSurface.goodInk),
      'rejected' => ('Rejected', AuraSurface.dangerBg, AuraSurface.dangerInk),
      _ => ('Unknown', AuraSurface.elevated, AuraSurface.faint),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
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
        color: verified ? AuraSurface.goodBg : AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: verified
              ? AuraSurface.goodInk.withValues(alpha: 0.4)
              : AuraSurface.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 10,
            color: verified ? AuraSurface.goodInk : AuraSurface.faint,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: verified ? AuraSurface.goodInk : AuraSurface.faint,
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
