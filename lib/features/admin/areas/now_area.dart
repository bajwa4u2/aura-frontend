/// NOW — the operator's current situation.
///
/// NOT A DASHBOARD ASSEMBLED FROM ENDPOINTS. It answers three questions, in
/// the order an operator asks them:
///
///   1. WHAT NEEDS MY ATTENTION?   work waiting, oldest first
///   2. WHAT IS UNHEALTHY?         the platform, in one line when it is fine
///   3. WHAT CHANGED?              decisions other operators made
///
/// THREE INDEPENDENT AUTHORITIES, THREE INDEPENDENT FAILURES.
/// The first version let one failed worklist read erase the spine of this
/// screen. Attention, health and change are separate reads now, and each says
/// its own piece when it cannot answer. NOW never collapses.
///
/// HIERARCHY IS THE POINT. Attention gets scale, position and colour; health
/// is a single line while healthy and expands only when it is not; change is a
/// quiet list. Rendering all three as equal cards would be the vanity
/// dashboard this replaced.
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
import '../domain/operator_signal.dart';
import '../ui/operator_kit.dart';
import 'record_area.dart' show readableReason;
import '../ui/operator_states.dart';

class NowArea extends ConsumerWidget {
  const NowArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final pad = wide ? AuraSpace.s20 : AuraSpace.s12;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, AuraSpace.s32),
          children: [
            const _Attention(),
            const SizedBox(height: AuraSpace.s24),
            _Health(authority: authority),
            const SizedBox(height: AuraSpace.s24),
            _Changed(authority: authority),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. WHAT NEEDS MY ATTENTION
// ═════════════════════════════════════════════════════════════════════════════

class _Attention extends ConsumerWidget {
  const _Attention();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signal = ref.watch(operatorWorkSummaryProvider);

    return _AttentionFrame(
      child: signal.when(
        loading: () => const OperatorLoading(lines: 3),
        // The provider turns transport failures into signals, so reaching here
        // means something unforeseen. Still a read failure, still not a queue.
        error: (_, __) => OperatorFailure(
          title: 'Work could not be counted',
          detail: 'This is a read failure, not an empty queue.',
          onRetry: () => ref.invalidate(operatorWorkSummaryProvider),
        ),
        data: (work) => OperatorSignalView<OperatorWorkSummary>(
          signal: work,
          subject: 'the worklist',
          unauthorizedNeeds: 'a queue you can work',
          onRetry: () => ref.invalidate(operatorWorkSummaryProvider),
          loading: const OperatorLoading(lines: 3),
          builder: (context, summary) => _AttentionBody(summary: summary),
        ),
      ),
    );
  }
}

class _AttentionFrame extends StatelessWidget {
  const _AttentionFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Needs your attention',
                  style: TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go(OperatorArea.work.path),
                child: const Text('Open worklist'),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _AttentionBody extends StatelessWidget {
  const _AttentionBody({required this.summary});

  final OperatorWorkSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.readable.isEmpty) {
      return const OperatorPanel(
        child: OperatorClear(
          title: 'No queue answered',
          detail: 'Nothing could be read, so nothing is known about what is '
              'waiting.',
          icon: Icons.help_outline_rounded,
        ),
      );
    }

    final pressing = summary.pressing;
    if (pressing.isEmpty) {
      // A RESULT, not an absence of one. An operator arriving to nothing
      // waiting should be told so plainly rather than shown a shrug.
      return OperatorPanel(
        child: OperatorClear(
          title: 'Nothing is waiting on you',
          detail: summary.complete
              ? 'Every queue you can work is empty.'
              : 'Every queue that answered is empty.',
          icon: Icons.check_circle_outline_rounded,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AttentionHeadline(summary: summary),
        const SizedBox(height: AuraSpace.s14),
        for (final source in pressing)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s8),
            child: _QueueRow(source: source),
          ),
      ],
    );
  }
}

/// One sentence an operator reads in a second — and it says so when the number
/// behind it is partial.
class _AttentionHeadline extends StatelessWidget {
  const _AttentionHeadline({required this.summary});

  final OperatorWorkSummary summary;

  @override
  Widget build(BuildContext context) {
    final queues = summary.pressing.length;
    final oldest = summary.pressing
        .map((s) => s.oldestAgeDays ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${summary.totalOpen}',
          style: TextStyle(
            color: oldest >= 14 ? AuraSurface.dangerInk : AuraSurface.ink,
            fontSize: 40,
            height: 1,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        Expanded(
          child: Text(
            summary.complete
                ? 'waiting across $queues ${queues == 1 ? 'queue' : 'queues'}'
                // A partial total must never read as a total.
                : 'waiting across the $queues '
                    '${queues == 1 ? 'queue' : 'queues'} that answered',
            style: const TextStyle(
              color: AuraSurface.muted,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
        if (oldest > 0) OperatorAge(days: oldest),
      ],
    );
  }
}

/// One queue: how much, what it is, how long, and the way in.
class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.source});

  final OperatorWorkSource source;

  @override
  Widget build(BuildContext context) {
    final age = source.oldestAgeDays ?? 0;
    final tone = age >= 14
        ? OperatorTone.danger
        : age >= 7
            ? OperatorTone.warn
            : OperatorTone.neutral;

    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.card),
        onTap: () => context.go(source.destination),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s14,
                AuraSpace.s12,
                AuraSpace.s14,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${source.open}',
                      style: TextStyle(
                        color: tone == OperatorTone.neutral
                            ? AuraSurface.ink
                            : tone.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      source.label,
                      style: const TextStyle(
                        color: AuraSurface.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (age > 0) ...[
                    // A GAP THAT SURVIVES 320px. Without it the queue name ran
                    // straight into "oldest" on a narrow phone — two unrelated
                    // facts reading as one string.
                    const SizedBox(width: AuraSpace.s10),
                    const Text(
                      'oldest',
                      style: TextStyle(color: AuraSurface.faint, fontSize: 11),
                    ),
                    const SizedBox(width: AuraSpace.s6),
                    OperatorAge(days: age, dense: true),
                  ],
                  const SizedBox(width: AuraSpace.s4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AuraSurface.faint,
                  ),
                ],
              ),
            ),
            if (tone != OperatorTone.neutral)
              Positioned(
                left: 0,
                top: AuraSpace.s8,
                bottom: AuraSpace.s8,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: tone.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. WHAT IS UNHEALTHY
// ═════════════════════════════════════════════════════════════════════════════

/// One line while everything is fine. Expands only when it is not.
///
/// Reads the canonical [PlatformHealth], never the payload — reasoning
/// directly from the payload is how a healthy platform came to be announced as
/// "5 services degraded" with two JSON objects rendered as status pills.
class _Health extends ConsumerWidget {
  const _Health({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.systemHealthRead)) {
      return const SizedBox.shrink();
    }

    final health = ref.watch(platformHealthProvider);

    return OperatorSection(
      title: 'Platform',
      trailing: TextButton(
        onPressed: () => context.go(OperatorArea.platform.path),
        child: const Text('Open'),
      ),
      child: health.when(
        loading: () => const OperatorPanel(child: OperatorLoading(lines: 1)),
        error: (_, __) => OperatorFailure(
          title: 'Platform health could not be read',
          detail: 'This is a read failure. It is not a statement about Aura.',
          onRetry: () => ref.invalidate(platformHealthProvider),
        ),
        data: (signal) => OperatorSignalView<PlatformHealth>(
          signal: signal,
          subject: 'platform health',
          unauthorizedNeeds: 'system health',
          onRetry: () => ref.invalidate(platformHealthProvider),
          loading: const OperatorPanel(child: OperatorLoading(lines: 1)),
          builder: (context, value) => _HealthBody(health: value),
        ),
      ),
    );
  }
}

class _HealthBody extends StatelessWidget {
  const _HealthBody({required this.health});

  final PlatformHealth health;

  @override
  Widget build(BuildContext context) {
    final condition = health.condition;

    // HEALTHY IS ONE LINE. A console that spends a third of its home screen on
    // five green ticks has taught the operator to stop reading it.
    if (condition == OperatorCondition.healthy) {
      return OperatorPanel(
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 16, color: AuraSurface.goodInk),
            const SizedBox(width: AuraSpace.s10),
            Text(
              health.summary,
              style: const TextStyle(color: AuraSurface.ink, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Anything else expands, worst first, showing ONLY what is not healthy.
    final notable = health.ordered
        .where((c) => c.condition != OperatorCondition.healthy)
        .toList();

    return OperatorPanel(
      tone: condition.isAdverse ? OperatorTone.danger : OperatorTone.warn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            health.summary,
            style: const TextStyle(
              color: AuraSurface.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          for (final check in notable)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: HealthCheckRow(check: check),
            ),
          if (health.healthy.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${health.healthy.length} other '
              '${health.healthy.length == 1 ? 'service is' : 'services are'} '
              'healthy.',
              style: const TextStyle(color: AuraSurface.faint, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// One dependency, as an operator reads it. Shared with PLATFORM so the two
/// surfaces cannot describe the same check differently.
class HealthCheckRow extends StatelessWidget {
  const HealthCheckRow({super.key, required this.check});

  final HealthCheck check;

  static OperatorTone toneFor(OperatorCondition condition) =>
      switch (condition) {
        OperatorCondition.failed => OperatorTone.danger,
        OperatorCondition.degraded => OperatorTone.warn,
        OperatorCondition.attention => OperatorTone.warn,
        // Not knowing is not an accusation, and must not be coloured like one.
        OperatorCondition.unknown => OperatorTone.neutral,
        OperatorCondition.healthy => OperatorTone.good,
      };

  static IconData iconFor(OperatorCondition condition) => switch (condition) {
        OperatorCondition.failed => Icons.error_rounded,
        OperatorCondition.degraded => Icons.warning_amber_rounded,
        OperatorCondition.attention => Icons.warning_amber_rounded,
        OperatorCondition.unknown => Icons.help_outline_rounded,
        OperatorCondition.healthy => Icons.check_circle_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(check.condition);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(iconFor(check.condition), size: 14, color: tone.ink),
        ),
        const SizedBox(width: AuraSpace.s8),
        SizedBox(
          width: 104,
          child: Text(
            check.label,
            style: const TextStyle(
              color: AuraSurface.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            // The source's own sentence, or the plain fact that it said
            // nothing. NEVER the payload.
            check.message ?? 'Nothing has reported on this.',
            style: const TextStyle(
              color: AuraSurface.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: AuraSpace.s8),
        OperatorStatePill(
          state: check.condition.label,
          tone: tone,
          dense: true,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. WHAT CHANGED
// ═════════════════════════════════════════════════════════════════════════════

/// A quiet list. Decisions, not requests.
class _Changed extends ConsumerWidget {
  const _Changed({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.auditRead)) {
      return const SizedBox.shrink();
    }

    final entries = ref.watch(adminAuditLogsProvider);

    return OperatorSection(
      title: 'What changed',
      trailing: TextButton(
        onPressed: () => context.go(OperatorArea.record.path),
        child: const Text('Record'),
      ),
      child: entries.when(
        loading: () => const OperatorPanel(child: OperatorLoading(lines: 2)),
        error: (_, __) => OperatorFailure(
          title: 'Recent decisions could not be read',
          onRetry: () => ref.invalidate(adminAuditLogsProvider),
        ),
        data: (all) {
          // DECISIONS, not reads. The audit log records everything an operator
          // did; "what changed" is only the part that changed something, and
          // filling this with `institution · members · list` would bury the one
          // revocation that matters.
          final decisions =
              all.where((e) => isOperatorDecision(e.action)).take(5).toList();

          if (decisions.isEmpty) {
            return const OperatorPanel(
              child: OperatorClear(
                title: 'Nothing has been decided recently',
                icon: Icons.history_rounded,
              ),
            );
          }

          return OperatorPanel(
            padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
            child: Column(
              children: [
                for (final entry in decisions)
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      readableAction(entry.action),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AuraSurface.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      entry.reason.isEmpty
                          ? entry.actorLabel
                          : '${entry.actorLabel} — '
                              '${readableReason(entry.reason)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AuraSurface.muted,
                      ),
                    ),
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
          );
        },
      ),
    );
  }
}

/// Whether an audit action CHANGED something.
///
/// Reads and refused attempts belong to RECORD, which is the complete account.
/// "What changed" is the short list of things that are now different.
bool isOperatorDecision(String action) {
  final lower = action.toLowerCase();
  if (lower.contains('.list') || lower.endsWith('.read')) return false;
  if (lower.contains('access.denied')) return false;
  if (lower.contains('.viewed') || lower.contains('.fetched')) return false;
  return true;
}

/// `admin.grant.revoked` → `Grant revoked`.
///
/// The dotted key is the server's identifier for an act; an operator reads a
/// sentence. Mechanical rather than a lookup table, so a new action never
/// renders as a blank — and never as `admin · grant · revoked`, which is the
/// key with punctuation swapped and still the server's vocabulary.
String readableAction(String action) {
  final parts = action.split('.').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return action;
  final meaningful = parts.first == 'admin' ? parts.sublist(1) : parts;
  if (meaningful.isEmpty) return action;

  final subject = meaningful.first.replaceAll('_', ' ');
  final verb = meaningful.length > 1
      ? meaningful.sublist(1).join(' ').replaceAll('_', ' ')
      : '';
  final sentence = verb.isEmpty ? subject : '$subject $verb';
  return sentence[0].toUpperCase() + sentence.substring(1);
}
