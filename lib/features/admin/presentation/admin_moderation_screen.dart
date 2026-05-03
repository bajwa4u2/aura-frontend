import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATUS FILTER
// ─────────────────────────────────────────────────────────────────────────────

enum _StatusFilter {
  all(null, 'All'),
  open('OPEN', 'Open'),
  underReview('UNDER_REVIEW', 'Under review'),
  needsContext('NEEDS_CONTEXT', 'Needs context'),
  reviewing('REVIEWING', 'Reviewing'),
  actionTaken('ACTION_TAKEN', 'Action taken'),
  resolved('RESOLVED', 'Resolved'),
  dismissed('DISMISSED', 'Dismissed');

  const _StatusFilter(this.value, this.label);
  final String? value;
  final String label;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AdminModerationScreen extends ConsumerStatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  ConsumerState<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends ConsumerState<AdminModerationScreen> {
  _StatusFilter _filter = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(adminModerationQueueProvider(_filter.value));

    return AuraScaffold(
      title: 'Moderation',
      showHomeAction: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            active: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: queueAsync.when(
              loading: () => const Center(
                child: AuraLoadingState(message: 'Loading queue…'),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: AuraErrorState(
                    title: 'Failed to load queue',
                    body: adminErrorMessage(e),
                    action: AuraSecondaryButton(
                      label: 'Retry',
                      icon: Icons.refresh_rounded,
                      onPressed: () => ref.invalidate(adminModerationQueueProvider(_filter.value)),
                    ),
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? _EmptyState(filter: _filter)
                  : _ReportList(
                      items: items,
                      onAction: _handleAction,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(ModerationReport report) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.page,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.xl)),
      ),
      builder: (_) => _ActionPanel(report: report, ref: ref),
    );
    if (result == true && mounted) {
      ref.invalidate(adminModerationQueueProvider(_filter.value));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.active, required this.onSelect});

  final _StatusFilter active;
  final ValueChanged<_StatusFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s16, vertical: AuraSpace.s8),
        children: _StatusFilter.values.map((f) {
          final selected = f == active;
          return Padding(
            padding: const EdgeInsets.only(right: AuraSpace.s8),
            child: GestureDetector(
              onTap: () => onSelect(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s12,
                  vertical: AuraSpace.s4,
                ),
                decoration: BoxDecoration(
                  color: selected ? AuraSurface.accentSoft : AuraSurface.elevated,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(
                    color: selected ? AuraSurface.accent : AuraSurface.divider,
                  ),
                ),
                child: Text(
                  f.label,
                  style: AuraText.label.copyWith(
                    color: selected ? AuraSurface.accentText : AuraSurface.muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORT LIST
// ─────────────────────────────────────────────────────────────────────────────

class _ReportList extends StatelessWidget {
  const _ReportList({required this.items, required this.onAction});

  final List<ModerationReport> items;
  final ValueChanged<ModerationReport> onAction;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s16, vertical: AuraSpace.s12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s8),
      itemBuilder: (_, i) => _ReportCard(report: items[i], onAction: onAction),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onAction});

  final ModerationReport report;
  final ValueChanged<ModerationReport> onAction;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(report.status);
    final fmt = DateFormat('MMM d, y');

    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        onTap: () => onAction(report),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeBadge(report.targetType),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(
                    child: Text(
                      report.reason,
                      style: AuraText.emphasis,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  _StatusChip(label: report.status, style: statusStyle),
                ],
              ),
              const SizedBox(height: AuraSpace.s8),
              if (report.details != null && report.details!.isNotEmpty) ...[
                Text(
                  report.details!,
                  style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AuraSpace.s6),
              ],
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 13, color: AuraSurface.faint),
                  const SizedBox(width: 4),
                  Text(
                    report.reporter.handle.isNotEmpty
                        ? '@${report.reporter.handle}'
                        : report.reporter.id,
                    style: AuraText.small.copyWith(color: AuraSurface.faint),
                  ),
                  const Spacer(),
                  Text(
                    fmt.format(report.createdAt.toLocal()),
                    style: AuraText.small.copyWith(color: AuraSurface.faint),
                  ),
                ],
              ),
              if (report.actions.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s6),
                Text(
                  '${report.actions.length} action${report.actions.length == 1 ? '' : 's'}',
                  style: AuraText.small.copyWith(color: AuraSurface.accentText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _StatusStyleData _statusStyle(String status) {
    return switch (status) {
      'OPEN' => const _StatusStyleData(AuraSurface.warnBg, AuraSurface.warnInk),
      'UNDER_REVIEW' || 'REVIEWING' => const _StatusStyleData(AuraSurface.infoBg, AuraSurface.infoInk),
      'NEEDS_CONTEXT' => const _StatusStyleData(AuraSurface.warnBg, AuraSurface.warnInk),
      'ACTION_TAKEN' || 'RESOLVED' => const _StatusStyleData(AuraSurface.goodBg, AuraSurface.goodInk),
      'DISMISSED' => const _StatusStyleData(AuraSurface.elevated, AuraSurface.muted),
      _ => const _StatusStyleData(AuraSurface.elevated, AuraSurface.muted),
    };
  }
}

class _StatusStyleData {
  const _StatusStyleData(this.bg, this.ink);
  final Color bg;
  final Color ink;
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGES & CHIPS
// ─────────────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.type);
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.sm),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        type,
        style: AuraText.label.copyWith(
          color: AuraSurface.muted,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.style});
  final String label;
  final _StatusStyleData style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: AuraText.label.copyWith(color: style.ink, fontSize: 10),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION PANEL (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionPanel extends StatefulWidget {
  const _ActionPanel({required this.report, required this.ref});
  final ModerationReport report;
  final WidgetRef ref;

  @override
  State<_ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends State<_ActionPanel> {
  final _noteCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _privateNoteCtrl = TextEditingController();
  String? _selectedAction;
  String _reportStatus = 'REVIEWING';
  bool _saving = false;

  static const _actionsByType = <String, List<String>>{
    'POST': ['NOTE', 'WARN', 'REQUEST_REVISION', 'SOFT_DELETE_POST', 'RESTORE_POST'],
    'USER': ['NOTE', 'WARN', 'REQUEST_CLARIFICATION', 'DISABLE_USER', 'RESTORE_USER'],
    'MESSAGE': ['NOTE', 'WARN', 'SOFT_DELETE_MESSAGE', 'RESTORE_MESSAGE'],
    'SPACE': ['NOTE', 'WARN', 'ARCHIVE_SPACE', 'RESTORE_SPACE'],
    'THREAD': ['NOTE', 'WARN', 'ARCHIVE_THREAD', 'RESTORE_THREAD'],
    'INSTITUTION': ['NOTE', 'WARN', 'SUSPEND_INSTITUTION', 'RESTORE_INSTITUTION'],
  };

  static const _statusOptions = [
    'REVIEWING',
    'UNDER_REVIEW',
    'NEEDS_CONTEXT',
    'ACTION_TAKEN',
    'RESOLVED',
    'DISMISSED',
  ];

  List<String> get _availableActions =>
      _actionsByType[widget.report.targetType] ?? ['NOTE', 'WARN'];

  @override
  void dispose() {
    _noteCtrl.dispose();
    _summaryCtrl.dispose();
    _privateNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PanelHeader(report: report),
            const SizedBox(height: AuraSpace.s16),

            // Action type
            Text('Action', style: AuraText.label.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s6),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s6,
              children: _availableActions.map((a) {
                final selected = _selectedAction == a;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAction = a),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? AuraSurface.accentSoft : AuraSurface.elevated,
                      borderRadius: BorderRadius.circular(AuraRadius.md),
                      border: Border.all(
                        color: selected ? AuraSurface.accent : AuraSurface.divider,
                      ),
                    ),
                    child: Text(
                      a,
                      style: AuraText.label.copyWith(
                        color: selected ? AuraSurface.accentText : AuraSurface.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AuraSpace.s14),

            // Report status
            Text('Update report status', style: AuraText.label.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s6),
            DropdownButtonFormField<String>(
              initialValue: _reportStatus,
              dropdownColor: AuraSurface.elevated,
              style: AuraText.body,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide: const BorderSide(color: AuraSurface.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide: const BorderSide(color: AuraSurface.divider),
                ),
              ),
              items: _statusOptions
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.replaceAll('_', ' '), style: AuraText.body),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _reportStatus = v ?? _reportStatus),
            ),
            const SizedBox(height: AuraSpace.s14),

            // Admin note (private)
            Text('Private note (admin only)', style: AuraText.label.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s6),
            TextField(
              controller: _privateNoteCtrl,
              maxLines: 2,
              style: AuraText.body,
              decoration: InputDecoration(
                hintText: 'Internal note — not visible to reporter',
                hintStyle: AuraText.small.copyWith(color: AuraSurface.faint),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide: const BorderSide(color: AuraSurface.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide: const BorderSide(color: AuraSurface.divider),
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s12),

            // Outcome summary (reporter-visible)
            Text('Outcome summary (reporter-visible)', style: AuraText.label.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s6),
            TextField(
              controller: _summaryCtrl,
              maxLines: 2,
              style: AuraText.body,
              decoration: InputDecoration(
                hintText: 'Brief outcome shared with the reporter',
                hintStyle: AuraText.small.copyWith(color: AuraSurface.faint),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide: const BorderSide(color: AuraSurface.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide: const BorderSide(color: AuraSurface.divider),
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s12),

            // Action note
            Text('Action note', style: AuraText.label.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s6),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              style: AuraText.body,
              decoration: InputDecoration(
                hintText: 'Optional note attached to this action',
                hintStyle: AuraText.small.copyWith(color: AuraSurface.faint),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide: const BorderSide(color: AuraSurface.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide: const BorderSide(color: AuraSurface.divider),
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_selectedAction == null || _saving) ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit action'),
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedAction == null) return;
    setState(() => _saving = true);
    try {
      final note = _noteCtrl.text.trim();
      final summary = _summaryCtrl.text.trim();
      final privateNote = _privateNoteCtrl.text.trim();
      await widget.ref.read(adminRepositoryProvider).submitModerationAction(
            actionType: _selectedAction!,
            targetType: widget.report.targetType,
            targetId: widget.report.targetId,
            reportId: widget.report.id,
            reportStatus: _reportStatus,
            note: note.isNotEmpty ? note : null,
            outcomeSummary: summary.isNotEmpty ? summary : null,
            privateNote: privateNote.isNotEmpty ? privateNote : null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AuraSurface.dangerBg,
            content: Text(
              'Failed: ${adminErrorMessage(e)}',
              style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.report});
  final ModerationReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: AuraSpace.s12),
          decoration: BoxDecoration(
            color: AuraSurface.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(
          children: [
            _TypeBadge(report.targetType),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(report.reason, style: AuraText.title, maxLines: 2),
            ),
          ],
        ),
        if (report.details != null && report.details!.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s6),
          Text(
            report.details!,
            style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.45),
          ),
        ],
        const SizedBox(height: AuraSpace.s8),
        Text(
          'Reporter: @${report.reporter.handle.isNotEmpty ? report.reporter.handle : report.reporter.id}  •  Target ID: ${report.targetId}',
          style: AuraText.small.copyWith(color: AuraSurface.faint),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final _StatusFilter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: AuraSurface.faint),
            const SizedBox(height: AuraSpace.s12),
            Text(
              filter == _StatusFilter.all
                  ? 'No reports in queue'
                  : 'No ${filter.label.toLowerCase()} reports',
              style: AuraText.emphasis,
            ),
            const SizedBox(height: AuraSpace.s6),
            Text(
              'Reports will appear here when users submit them.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
