/// INTEGRITY — Aura's responsibility for what is said and what is held.
///
/// NOT four old screens under one heading. The operator responsibility here is
/// a single one: when somebody's conduct, somebody's file, or somebody's words
/// are in question, a human decides — and the decision is evidenced, bounded
/// by policy, consequential, and recorded.
///
/// So the area is organised by WHAT KIND OF JUDGEMENT IS BEING ASKED, not by
/// which backend owns the row:
///
///   CONDUCT      somebody reported somebody. Evidence: what they said.
///   CUSTODY      Aura is holding a file. Evidence: why, and the appeal.
///   VOICE        people told us about the product, or asked us for help.
///   GOVERNANCE   what Aura itself may send, and who approves it.
///
/// EACH QUEUE FAILS ALONE. The first version read one summary and blanked the
/// entire conduct half when it failed. Every queue below carries its own
/// count, its own reachability and its own sentence when it cannot answer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/operator_work.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_kit.dart';
import '../ui/operator_states.dart';

/// The judgement families, and which queues answer to each.
///
/// A GROUPING BY RESPONSIBILITY, not by service. `MODERATION` and
/// `MEDIA_APPEAL` are different authorities that ask the operator for the same
/// kind of decision, and an operator working through the morning thinks in
/// those terms rather than in table names.
class _Family {
  const _Family({
    required this.title,
    required this.question,
    required this.sources,
    required this.needs,
    required this.icon,
  });

  final String title;

  /// The judgement, in the operator's words. This is the whole reason the
  /// grouping exists and it is written on the screen, not just here.
  final String question;

  final List<String> sources;
  final OperatorCapability needs;
  final IconData icon;
}

const _families = <_Family>[
  _Family(
    title: 'Conduct',
    question: 'Somebody reported somebody. Does Aura act?',
    sources: ['MODERATION'],
    needs: OperatorCapability.moderationRead,
    icon: Icons.flag_rounded,
  ),
  _Family(
    title: 'Custody',
    question: 'Aura is holding a file. Should it still be?',
    sources: ['MEDIA_APPEAL'],
    needs: OperatorCapability.moderationRead,
    icon: Icons.lock_rounded,
  ),
  _Family(
    // A PERSON ASKED AURA TO SAY WHO THEY ARE, and attached a government
    // document and a photograph to the request. That is evidence, judgement,
    // consequence and record — the same shape as every other family here, and
    // it had no operator surface at all until this pass.
    title: 'Identity',
    question: 'Somebody says this is who they are. Does the evidence show it?',
    sources: ['IDENTITY_VERIFICATION'],
    needs: OperatorCapability.identityVerificationRead,
    icon: Icons.badge_outlined,
  ),
  _Family(
    title: 'What people told us',
    question: 'Somebody wrote to us. What did we do about it?',
    sources: ['PRODUCT_FEEDBACK', 'SUPPORT'],
    needs: OperatorCapability.productFeedbackRead,
    icon: Icons.forum_rounded,
  ),
];

class IntegrityArea extends ConsumerWidget {
  const IntegrityArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();
    final summary = ref.watch(operatorWorkSummaryProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final pad = wide ? AuraSpace.s20 : AuraSpace.s12;

        return ListView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, AuraSpace.s32),
          children: [
            const Text(
              'What requires judgement',
              style: TextStyle(
                color: AuraSurface.ink,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Each of these is a decision only a person can make. Aura holds '
              'the record; it does not make the call.',
              style: TextStyle(
                color: AuraSurface.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            summary.when(
              loading: () => const OperatorLoading(lines: 4),
              error: (_, __) => OperatorFailure(
                title: 'Integrity queues could not be read',
                detail: 'This is a read failure. Nothing has been resolved or '
                    'lost.',
                onRetry: () => ref.invalidate(operatorWorkSummaryProvider),
              ),
              data: (signal) => OperatorSignalView<OperatorWorkSummary>(
                signal: signal,
                subject: 'the integrity queues',
                unauthorizedNeeds: 'moderation',
                onRetry: () => ref.invalidate(operatorWorkSummaryProvider),
                loading: const OperatorLoading(lines: 4),
                builder: (context, work) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final family in _families)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpace.s16),
                        child: _FamilyCard(
                          family: family,
                          work: work,
                          authority: authority,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
            _Governance(authority: authority),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// One judgement family: the question, then each queue that answers it.
class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.family,
    required this.work,
    required this.authority,
  });

  final _Family family;
  final OperatorWorkSummary work;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context) {
    if (!authority.can(family.needs)) {
      return OperatorSection(
        title: family.title,
        child: OperatorInsufficientCapability(needs: family.title.toLowerCase()),
      );
    }

    final queues = work.sources
        .where((s) => family.sources.contains(s.source))
        .toList(growable: false);

    if (queues.isEmpty) {
      // The operator holds the family's read capability but no queue in it
      // was returned — a real thing to say, and different from "empty".
      return OperatorSection(
        title: family.title,
        subtitle: family.question,
        child: const OperatorPanel(
          child: OperatorClear(
            title: 'No queue in this family reported',
            icon: Icons.help_outline_rounded,
          ),
        ),
      );
    }

    final waiting = queues
        .where((q) => q.readable)
        .fold<int>(0, (sum, q) => sum + q.open);
    final unreadable = queues.where((q) => !q.readable).toList();

    return OperatorSection(
      title: family.title,
      subtitle: family.question,
      trailing: waiting == 0
          ? null
          : Text(
              '$waiting waiting',
              style: const TextStyle(
                color: AuraSurface.muted,
                fontSize: 12.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      child: OperatorPanel(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
        child: Column(
          children: [
            for (final queue in queues) _QueueLine(queue: queue),
            if (unreadable.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s12,
                  AuraSpace.s4,
                  AuraSpace.s12,
                  AuraSpace.s10,
                ),
                child: Text(
                  // Named, so an operator knows this family's picture is
                  // incomplete rather than clear.
                  unreadable.map((q) => q.unavailableSentence).join(' '),
                  style: const TextStyle(
                    color: AuraSurface.dangerInk,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QueueLine extends StatelessWidget {
  const _QueueLine({required this.queue});

  final OperatorWorkSource queue;

  @override
  Widget build(BuildContext context) {
    if (!queue.readable) {
      return ListTile(
        dense: true,
        enabled: false,
        leading: const Icon(Icons.cloud_off_rounded,
            size: 16, color: AuraSurface.faint),
        title: Text(
          queue.label,
          style: const TextStyle(color: AuraSurface.faint, fontSize: 13),
        ),
        // An em dash, never 0 — the count is unknown, not zero.
        trailing: const Text(
          '—',
          style: TextStyle(color: AuraSurface.faint, fontSize: 13),
        ),
      );
    }

    final age = queue.oldestAgeDays ?? 0;

    return ListTile(
      dense: true,
      onTap: () => context.go(queue.destination),
      title: Text(
        queue.label,
        style: const TextStyle(color: AuraSurface.ink, fontSize: 13),
      ),
      subtitle: queue.open == 0
          ? const Text(
              'Nothing waiting',
              style: TextStyle(color: AuraSurface.faint, fontSize: 11.5),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AGE WHENEVER THERE IS WORK, INCLUDING AT ZERO. Gated on `age > 0`
          // this left a blank beside a queue whose oldest item arrived TODAY,
          // next to sibling queues that carried an age — which reads as
          // missing data on the queue that is most up to date.
          if (queue.open > 0) ...[
            OperatorAge(days: age, dense: true),
            const SizedBox(width: AuraSpace.s10),
          ],
          Text(
            '${queue.open}',
            style: TextStyle(
              color: queue.open == 0 ? AuraSurface.faint : AuraSurface.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AuraSpace.s6),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AuraSurface.faint),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// COMMUNICATION IS GOVERNED HERE, NOT PERFORMED HERE.
///
/// Composition, audience and delivery belong to the communication authority.
/// What lives in Admin is the decision to approve and the decision to send —
/// and the record of who made them. The console will not become a newsletter
/// tool again.
class _Governance extends StatelessWidget {
  const _Governance({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context) {
    const decisions = <(String, String, OperatorCapability)>[
      (
        'Read',
        'See what Aura is preparing to send.',
        OperatorCapability.communicationsRead,
      ),
      (
        'Approve',
        'Say a message may go out.',
        OperatorCapability.communicationsApprove,
      ),
      (
        'Send',
        'Release an approved message to its audience.',
        OperatorCapability.communicationsSend,
      ),
    ];

    final held = decisions.where((d) => authority.can(d.$3)).toList();
    if (held.isEmpty) return const SizedBox.shrink();

    return OperatorSection(
      title: 'What Aura may say',
      subtitle: 'Admin governs outbound communication. It does not compose it.',
      child: OperatorPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final decision in held)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_rounded,
                          size: 14, color: AuraSurface.goodInk),
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    SizedBox(
                      width: 76,
                      child: Text(
                        decision.$1,
                        style: const TextStyle(
                          color: AuraSurface.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        decision.$2,
                        style: const TextStyle(
                          color: AuraSurface.muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s12,
                AuraSpace.s10,
                AuraSpace.s12,
                AuraSpace.s10,
              ),
              decoration: BoxDecoration(
                color: AuraSurface.page,
                borderRadius: BorderRadius.circular(AuraRadius.md),
              ),
              child: const Text(
                'Drafting, audience and delivery belong to the communication '
                'authority. What lives here is the decision to approve, the '
                'decision to send, and the record of who made them.',
                style: TextStyle(
                  color: AuraSurface.muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
