/// NOW — the operator situation view.
///
/// This replaces a launcher grid of links grouped by backend concepts
/// (Database, Email, Devices, Content, Governance). An operator opening Aura
/// Admin should understand the state of Aura in seconds without knowing what a
/// module is called.
///
/// It answers, in priority order:
///   1. WHAT NEEDS ATTENTION  — work, oldest first, only what you can act on
///   2. WHAT IS DEGRADED      — health, failures first, silence when fine
///   3. WHAT CHANGED          — recent governed actions
///
/// HIERARCHY IS THE POINT. Attention gets scale and position; health is a
/// single line when healthy and expands only when it isn't; change is a quiet
/// list. Rendering all three as equal cards would be a vanity dashboard, which
/// is the thing being demolished.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../data/operator_work.dart';
import '../domain/operator_area.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_kit.dart';

class NowArea extends ConsumerWidget {
  const NowArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(operatorWorkSummaryProvider);
            if (authority.can(OperatorCapability.systemHealthRead)) {
              ref.invalidate(adminHealthProvider);
            }
            if (authority.can(OperatorCapability.auditRead)) {
              ref.invalidate(adminAuditLogsProvider);
            }
            await ref.read(operatorWorkSummaryProvider.future);
          },
          child: ListView(
            padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
            children: [
              // Centred reading column. NOW is read, not scanned in bulk, and
              // a full-bleed row at 1440 puts its label and its affordance a
              // screen apart.
              // ATTENTION FIRST, always. It is the only section that earns
              // full width and full weight.
              const _AttentionBlock(),

              if (authority.can(OperatorCapability.systemHealthRead)) ...[
                const SizedBox(height: AuraSpace.s20),
                const _HealthBlock(),
              ],

              if (authority.can(OperatorCapability.auditRead)) ...[
                const SizedBox(height: AuraSpace.s20),
                const _ChangedBlock(),
              ],

              // An operator whose authority covers none of the above still
              // gets an honest answer rather than a blank page.
              if (!authority.can(OperatorCapability.systemHealthRead) &&
                  !authority.can(OperatorCapability.auditRead))
                const Padding(
                  padding: EdgeInsets.only(top: AuraSpace.s20),
                  child: OperatorInsufficientCapability(
                    needs: 'health or audit',
                  ),
                ),
            ].map((w) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: w,
                  ),
                )).toList(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENTION
// ─────────────────────────────────────────────────────────────────────────────

class _AttentionBlock extends ConsumerWidget {
  const _AttentionBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(operatorWorkSummaryProvider);

    return summary.when(
      loading: () => const OperatorSection(
        title: 'Needs attention',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'Needs attention',
        child: OperatorFailure(
          title: 'Work could not be counted',
          detail: 'This is a read failure, not an empty queue.',
          onRetry: () => ref.invalidate(operatorWorkSummaryProvider),
        ),
      ),
      data: (s) {
        if (s.sources.isEmpty) {
          return const OperatorSection(
            title: 'Needs attention',
            child: OperatorInsufficientCapability(needs: 'any queue'),
          );
        }

        if (s.isClear) {
          return const OperatorSection(
            title: 'Needs attention',
            child: OperatorClear(
              title: 'Nothing needs your attention',
              detail: 'Every queue you hold authority over is clear.',
            ),
          );
        }

        final active = s.sources
            .where((x) => x.readable && x.open > 0)
            .toList()
          ..sort((a, b) =>
              (b.oldestAgeDays ?? 0).compareTo(a.oldestAgeDays ?? 0));

        return OperatorSection(
          title: 'Needs attention',
          subtitle: '${s.totalOpen} open across '
              '${active.length} queue${active.length == 1 ? '' : 's'}',
          trailing: TextButton(
            onPressed: () => context.go(OperatorArea.work.path),
            child: const Text('Open worklist'),
          ),
          child: Column(
            children: [
              for (final source in active)
                Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                  child: _QueueRow(source: source),
                ),
              if (s.isDegraded)
                Padding(
                  padding: const EdgeInsets.only(top: AuraSpace.s4),
                  child: OperatorFailure(
                    title: '${s.degradedSources.length} queue'
                        '${s.degradedSources.length == 1 ? '' : 's'} unavailable',
                    detail:
                        'Excluded from the count rather than reported as zero.',
                    onRetry: () =>
                        ref.invalidate(operatorWorkSummaryProvider),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.source});

  final OperatorWorkSourceSummary source;

  @override
  Widget build(BuildContext context) {
    final oldest = source.oldestAgeDays ?? 0;
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.card),
        onTap: () => context.go(source.destination),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              // The count carries the weight — it is the number an operator
              // came here to read.
              SizedBox(
                width: 46,
                child: Text(
                  '${source.open}',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: oldest >= 14
                        ? AuraSurface.dangerInk
                        : oldest >= 7
                            ? AuraSurface.warnInk
                            : AuraSurface.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  source.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AuraSurface.ink,
                  ),
                ),
              ),
              if (source.oldestAgeDays != null) ...[
                const Text(
                  'oldest',
                  style: TextStyle(
                    fontSize: 11,
                    color: AuraSurface.faint,
                  ),
                ),
                const SizedBox(width: AuraSpace.s8),
                SizedBox(
                  width: 76,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OperatorAge(days: source.oldestAgeDays!),
                  ),
                ),
              ],
              const SizedBox(width: AuraSpace.s12),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AuraSurface.faint),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEALTH — one line when fine, expanded only when it is not
// ─────────────────────────────────────────────────────────────────────────────

class _HealthBlock extends ConsumerWidget {
  const _HealthBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(adminHealthProvider);

    return health.when(
      loading: () => const OperatorSection(
        title: 'Platform',
        child: OperatorLoading(lines: 1),
      ),
      error: (e, _) => OperatorSection(
        title: 'Platform',
        child: OperatorFailure(
          title: 'Health could not be read',
          detail: 'Aura may be fine — this is the health check failing.',
          onRetry: () => ref.invalidate(adminHealthProvider),
        ),
      ),
      data: (h) {
        if (h == null) {
          // Authority held, no snapshot returned. Neither healthy nor broken —
          // and saying "all services healthy" here would be a guess.
          return const OperatorSection(
            title: 'Platform',
            child: OperatorPanel(
              padding: EdgeInsets.symmetric(
                horizontal: AuraSpace.s16,
                vertical: AuraSpace.s12,
              ),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      size: 16, color: AuraSurface.muted),
                  SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Text(
                      'Health is unknown — no snapshot was returned.',
                      style: TextStyle(fontSize: 13, color: AuraSurface.muted),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final services = <String, String>{
          'API': h.apiStatus,
          'Database': h.dbStatus,
          'Realtime': h.realtimeStatus,
          'Email': h.emailStatus,
          'Push': h.pushStatus,
        };
        final degraded = services.entries
            .where((e) => e.value.toLowerCase() != 'ok')
            .toList();

        if (degraded.isEmpty) {
          // Healthy is one quiet line. Five green cards would train an
          // operator to stop reading this section.
          return OperatorSection(
            title: 'Platform',
            child: OperatorPanel(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s16,
                vertical: AuraSpace.s12,
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: AuraSurface.goodInk),
                  const SizedBox(width: AuraSpace.s10),
                  const Expanded(
                    child: Text(
                      'All services healthy',
                      style: TextStyle(
                          fontSize: 13, color: AuraSurface.ink),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(OperatorArea.platform.path),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          );
        }

        return OperatorSection(
          title: 'Platform',
          subtitle: '${degraded.length} service'
              '${degraded.length == 1 ? '' : 's'} degraded',
          trailing: TextButton(
            onPressed: () => context.go(OperatorArea.platform.path),
            child: const Text('Open'),
          ),
          child: OperatorPanel(
            tone: OperatorTone.danger,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in degraded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AuraSurface.ink,
                            ),
                          ),
                        ),
                        OperatorStatePill(
                          state: entry.value.toUpperCase(),
                          tone: OperatorTone.danger,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WHAT CHANGED
// ─────────────────────────────────────────────────────────────────────────────

class _ChangedBlock extends ConsumerWidget {
  const _ChangedBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminAuditLogsProvider);

    return logs.when(
      loading: () => const OperatorSection(
        title: 'What changed',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'What changed',
        child: OperatorFailure(
          title: 'Recent actions could not be read',
          onRetry: () => ref.invalidate(adminAuditLogsProvider),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const OperatorSection(
            title: 'What changed',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No recent operator actions',
                icon: Icons.history_rounded,
              ),
            ),
          );
        }
        final recent = entries.take(6).toList();
        return OperatorSection(
          title: 'What changed',
          trailing: TextButton(
            onPressed: () => context.go(OperatorArea.record.path),
            child: const Text('Record'),
          ),
          child: OperatorPanel(
            padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
            child: Column(
              children: [
                for (final entry in recent)
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      entry.action.replaceAll('.', ' · '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AuraSurface.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      // Actor and authority are the point of a record. A row
                      // that says only what happened is a log line, not audit.
                      entry.reason.isEmpty
                          ? entry.actorLabel
                          : '${entry.actorLabel} — ${entry.reason}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: AuraSurface.muted),
                    ),
                    // A failed attempt is a different fact from a completed
                    // act, and the record must not read them the same way.
                    trailing: entry.failed
                        ? const OperatorStatePill(
                            state: 'FAILED',
                            tone: OperatorTone.danger,
                            dense: true,
                          )
                        : null,
                    onTap: () => context.go(OperatorArea.record.path),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
