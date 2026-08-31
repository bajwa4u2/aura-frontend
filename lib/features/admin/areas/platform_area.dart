/// PLATFORM — health, the released-client fleet, and release governance.
///
/// This is operator platform governance, not developer tooling. The
/// convergence-report screen that used to live in this navigation was
/// engineering evidence for a one-off sign-off and does not belong to an
/// operator; it is retired from here.
///
/// The fleet section exists because the authority behind it already did and
/// nothing consumed it. It answers the question every release consequence
/// turns on: which versions are actually out there, and what is failing to
/// talk to us.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../data/client_fleet.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_kit.dart';

class PlatformArea extends ConsumerWidget {
  const PlatformArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return ListView(
          padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
          children: [
            if (authority.can(OperatorCapability.systemHealthRead))
              const _ServiceHealth()
            else
              const OperatorSection(
                title: 'Service health',
                child: OperatorInsufficientCapability(needs: 'system health'),
              ),
            const SizedBox(height: AuraSpace.s24),
            if (authority.can(OperatorCapability.analyticsRead))
              _Fleet(wide: wide)
            else
              const OperatorSection(
                title: 'Released clients',
                child: OperatorInsufficientCapability(needs: 'analytics'),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ServiceHealth extends ConsumerWidget {
  const _ServiceHealth();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(adminHealthProvider);

    return health.when(
      loading: () => const OperatorSection(
        title: 'Service health',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'Service health',
        child: OperatorFailure(
          title: 'Health could not be read',
          detail: 'Aura may be fine — this is the health check failing.',
          onRetry: () => ref.invalidate(adminHealthProvider),
        ),
      ),
      data: (h) {
        if (h == null) {
          return const OperatorSection(
            title: 'Service health',
            child: OperatorPanel(
              child: Text(
                'No health snapshot was returned. This is unknown, not healthy.',
                style: TextStyle(color: AuraSurface.muted, fontSize: 13),
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
        // Degraded first. An operator opening PLATFORM is usually looking for
        // what is wrong, and making them read past four healthy rows to find
        // it is the wrong hierarchy.
        final ordered = services.entries.toList()
          ..sort((a, b) {
            final aOk = a.value.toLowerCase() == 'ok';
            final bOk = b.value.toLowerCase() == 'ok';
            if (aOk == bOk) return a.key.compareTo(b.key);
            return aOk ? 1 : -1;
          });
        final degraded =
            ordered.where((e) => e.value.toLowerCase() != 'ok').length;

        return OperatorSection(
          title: 'Service health',
          subtitle: degraded == 0
              ? 'All services healthy'
              : '$degraded of ${services.length} degraded',
          child: OperatorPanel(
            tone: degraded == 0 ? null : OperatorTone.danger,
            child: Column(
              children: [
                for (final entry in ordered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                    child: Row(
                      children: [
                        Icon(
                          entry.value.toLowerCase() == 'ok'
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          size: 15,
                          color: entry.value.toLowerCase() == 'ok'
                              ? AuraSurface.goodInk
                              : AuraSurface.dangerInk,
                        ),
                        const SizedBox(width: AuraSpace.s10),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                                color: AuraSurface.ink, fontSize: 13),
                          ),
                        ),
                        OperatorStatePill(
                          state: entry.value.toUpperCase(),
                          tone: entry.value.toLowerCase() == 'ok'
                              ? OperatorTone.good
                              : OperatorTone.danger,
                          dense: true,
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

class _Fleet extends ConsumerWidget {
  const _Fleet({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(clientFleetProvider);

    return fleet.when(
      loading: () => const OperatorSection(
        title: 'Released clients',
        child: OperatorLoading(lines: 3),
      ),
      error: (e, _) => OperatorSection(
        title: 'Released clients',
        child: OperatorFailure(
          title: 'Fleet observations could not be read',
          onRetry: () => ref.invalidate(clientFleetProvider),
        ),
      ),
      data: (f) {
        if (f.isSilent) {
          // Silence is not health. A fleet reporting nothing may mean nobody
          // is running Aura, or may mean observation is broken.
          return const OperatorSection(
            title: 'Released clients',
            child: OperatorPanel(
              child: Text(
                'No client observations in this window. That is not the same '
                'as a healthy fleet — it may mean nothing is reporting.',
                style: TextStyle(
                    color: AuraSurface.muted, fontSize: 13, height: 1.4),
              ),
            ),
          );
        }

        final totalIncompatible =
            f.incompatible.fold<int>(0, (sum, i) => sum + i.count);

        return OperatorSection(
          title: 'Released clients',
          subtitle: '${f.uniqueClients} client'
              '${f.uniqueClients == 1 ? '' : 's'} seen over '
              '${(f.windowHours / 24).round()} days',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (totalIncompatible > 0) ...[
                OperatorPanel(
                  tone: OperatorTone.danger,
                  child: Row(
                    children: [
                      const Icon(Icons.phonelink_off_rounded,
                          size: 18, color: AuraSurface.dangerInk),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: Text(
                          '$totalIncompatible incompatible connection '
                          'attempt${totalIncompatible == 1 ? '' : 's'} — '
                          'clients that could not talk to this server.',
                          style: const TextStyle(
                              color: AuraSurface.ink,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
              ],
              OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final d in f.distributions)
                      _FleetBar(
                        label: '${d.distribution} · ${d.channel}',
                        count: d.count,
                        percentage: d.percentage,
                      ),
                    if (f.stale.any((s) => s.staleCount > 0)) ...[
                      const SizedBox(height: AuraSpace.s12),
                      const Divider(color: AuraSurface.divider, height: 1),
                      const SizedBox(height: AuraSpace.s12),
                      const Text(
                        'RUNNING A STALE VERSION',
                        style: TextStyle(
                          color: AuraSurface.faint,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      for (final s
                          in f.stale.where((s) => s.staleCount > 0))
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AuraSpace.s6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${s.distribution} · ${s.channel}',
                                  style: const TextStyle(
                                      color: AuraSurface.ink, fontSize: 12.5),
                                ),
                              ),
                              Text(
                                '${s.staleCount}/${s.totalCount}',
                                style: const TextStyle(
                                  color: AuraSurface.warnInk,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A proportion bar. A chart here earns its place: "which distribution is most
/// of our fleet" is a comparison, and a comparison reads faster as length than
/// as a column of numbers.
class _FleetBar extends StatelessWidget {
  const _FleetBar({
    required this.label,
    required this.count,
    required this.percentage,
  });

  final String label;
  final int count;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final fraction = (percentage / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: AuraSurface.ink, fontSize: 12.5),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: AuraSurface.muted,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              SizedBox(
                width: 44,
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AuraSurface.accentText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AuraRadius.sm),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: AuraSurface.elevated,
              color: AuraSurface.accent,
            ),
          ),
        ],
      ),
    );
  }
}
