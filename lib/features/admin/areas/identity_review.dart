/// IDENTITY REVIEW — the judgement Aura could make but never offered.
///
/// A person submitted a government document and a photograph and asked Aura to
/// say they are who they claim to be. The authority for deciding that has been
/// complete for some time. The operator console never called it.
///
/// This is the review, and it belongs in INTEGRITY for the same reason a
/// moderation report does: a human is being asked to look at evidence and make
/// a consequential decision about a person. WORK routes here; SUBJECTS shows
/// that it is waiting; RECORD keeps the decision.
///
/// THE ORDER IS DELIBERATE AND IT IS THE WHOLE DESIGN
/// --------------------------------------------------
///   1. WHO is asking, and what they have asked before.
///   2. THE EVIDENCE — opened one piece at a time, each open audited.
///   3. THE DECISION, with its reason and its consequence stated first.
///
/// A reviewer who decides before opening the evidence has not reviewed
/// anything, so the verdict sits below the evidence and the console says what
/// is missing when it is missing.
///
/// CUSTODY IS NOT RELAXED FOR CONVENIENCE
/// --------------------------------------
/// No image is fetched by opening this screen. Each piece of evidence is
/// fetched only when the operator asks for it, through the one endpoint that
/// writes an audit row naming who looked at whose identity document first and
/// opens the media door second. Nothing here prefetches, caches to disk, or
/// keeps a URL after the screen is left.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/operator_identity.dart';
import '../data/operator_work.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../domain/operator_routes.dart';
import '../ui/operator_action.dart';
import '../ui/operator_kit.dart';
import '../ui/operator_states.dart';

class IdentityReviewDetail extends ConsumerWidget {
  const IdentityReviewDetail({super.key, required this.submissionId});

  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    // The console asks the same question the server will ask. A visible
    // surface and a working request must never disagree.
    if (!authority.can(OperatorCapability.identityVerificationRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'identity verification'),
      );
    }

    final submission = ref.watch(identitySubmissionProvider(submissionId));

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final pad = wide ? AuraSpace.s20 : AuraSpace.s12;

        return submission.when(
          loading: () => Padding(
            padding: EdgeInsets.all(pad),
            child: const OperatorLoading(lines: 5),
          ),
          error: (_, __) => Padding(
            padding: EdgeInsets.all(pad),
            child: OperatorFailure(
              title: 'This submission could not be read',
              detail: 'This is a read failure. Nothing has been decided.',
              onRetry: () =>
                  ref.invalidate(identitySubmissionProvider(submissionId)),
            ),
          ),
          data: (signal) => Padding(
            padding: EdgeInsets.all(pad),
            child: OperatorSignalView<IdentitySubmission>(
              signal: signal,
              subject: 'this identity submission',
              unauthorizedNeeds: 'identity verification',
              onRetry: () =>
                  ref.invalidate(identitySubmissionProvider(submissionId)),
              builder: (context, s) => ListView(
                padding: EdgeInsets.zero,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Who(submission: s),
                          const SizedBox(height: AuraSpace.s20),
                          _Evidence(submission: s, authority: authority),
                          const SizedBox(height: AuraSpace.s20),
                          if (s.history.isNotEmpty) ...[
                            _History(submission: s),
                            const SizedBox(height: AuraSpace.s20),
                          ],
                          _Decision(
                            submission: s,
                            authority: authority,
                            onDecided: () {
                              ref.invalidate(
                                  identitySubmissionProvider(submissionId));
                              ref.invalidate(identityQueueProvider);
                              ref.invalidate(operatorWorkSummaryProvider);
                              ref.invalidate(operatorWorkListProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WHO IS ASKING
// ═════════════════════════════════════════════════════════════════════════════

class _Who extends StatelessWidget {
  const _Who({required this.submission});

  final IdentitySubmission submission;

  @override
  Widget build(BuildContext context) {
    final person = submission.subject;
    final name = person.displayName.trim().isNotEmpty
        ? person.displayName.trim()
        : (person.handle.trim().isNotEmpty ? '@${person.handle.trim()}' : null);

    return OperatorSection(
      title: 'Who is asking',
      subtitle: 'They have asked Aura to say they are who they claim to be.',
      trailing: OperatorStatePill(
        state: submission.state.label,
        tone: submission.awaitsDecision
            ? OperatorTone.pending
            : OperatorTone.neutral,
      ),
      child: OperatorPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name ?? 'Somebody who has since left',
                    style: const TextStyle(
                      color: AuraSurface.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // The subject is openable: "who is this person" and "what is
                // being decided about them" are one investigation.
                if (person.userId.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        context.go(operatorPersonRoute(person.userId)),
                    style: TextButton.styleFrom(
                      foregroundColor: AuraSurface.accent,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Open the person'),
                  ),
              ],
            ),
            if (person.handle.trim().isNotEmpty && name != '@${person.handle}')
              Text(
                '@${person.handle.trim()}',
                style: const TextStyle(
                    color: AuraSurface.muted, fontSize: 12.5),
              ),
            const SizedBox(height: AuraSpace.s12),
            if (submission.submittedAt != null)
              _Row(
                label: 'Submitted',
                value: AuraTemporal.humanize(
                  ProductTime(submission.submittedAt!, TimeEvent.received),
                ),
              ),
            if (submission.documentType != null)
              _Row(label: 'Document', value: submission.documentType!),
            if (submission.documentExpiresAt != null)
              _Row(
                label: 'Document expires',
                value: _day(submission.documentExpiresAt!),
                // An expired document is a real reason to refuse, and the
                // reviewer should not have to work the date out.
                tone: submission.documentExpiresAt!.isBefore(DateTime.now())
                    ? OperatorTone.danger
                    : null,
              ),
            if (submission.tier != null)
              _Row(label: 'Assurance', value: _tier(submission.tier!)),
          ],
        ),
      ),
    );
  }

  static String _tier(String wire) => switch (wire.toUpperCase()) {
        'BASE' => 'Base — general use',
        'ELEVATED' => 'Elevated — required for institution onboarding',
        _ => wire,
      };
}

// ═════════════════════════════════════════════════════════════════════════════
// THE EVIDENCE
// ═════════════════════════════════════════════════════════════════════════════

/// Each piece opened on request, one at a time, and each open recorded.
class _Evidence extends ConsumerStatefulWidget {
  const _Evidence({required this.submission, required this.authority});

  final IdentitySubmission submission;
  final OperatorAuthority authority;

  @override
  ConsumerState<_Evidence> createState() => _EvidenceState();
}

class _EvidenceState extends ConsumerState<_Evidence> {
  /// Opened evidence, by id. Held in memory for this screen only — never
  /// persisted, never prefetched, and gone when the operator leaves.
  final Map<String, IdentityEvidenceView> _opened = {};
  final Set<String> _opening = {};
  final Map<String, String> _failed = {};

  Future<void> _open(IdentityEvidence evidence) async {
    setState(() {
      _opening.add(evidence.id);
      _failed.remove(evidence.id);
    });
    try {
      final view = await ref
          .read(operatorIdentityRepositoryProvider)
          .viewEvidence(evidence.id);
      if (!mounted) return;
      setState(() => _opened[evidence.id] = view);
    } catch (e) {
      if (!mounted) return;
      setState(() => _failed[evidence.id] =
          'This could not be opened. Nothing was recorded as seen.');
    } finally {
      if (mounted) setState(() => _opening.remove(evidence.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;

    if (s.evidence.isEmpty) {
      return const OperatorSection(
        title: 'The evidence',
        child: OperatorPanel(
          child: OperatorClear(
            title: 'No evidence was attached',
            detail: 'There is nothing here to judge. A submission with no '
                'evidence cannot be approved.',
            icon: Icons.hide_image_outlined,
          ),
        ),
      );
    }

    final allDiscarded = s.evidence.every((e) => e.discarded);

    return OperatorSection(
      title: 'The evidence',
      subtitle: allDiscarded
          ? null
          : 'Opening a document is recorded against your name.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (allDiscarded) ...[
            OperatorPanel(
              tone: OperatorTone.warn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This evidence was destroyed on schedule.',
                    style: TextStyle(
                      color: AuraSurface.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.evidenceDiscardedAt == null
                        ? 'The record that it existed survives; the images do '
                            'not. Aura does not keep identity documents once '
                            'their retention window closes.'
                        : 'Destroyed ${AuraTemporal.humanize(ProductTime(s.evidenceDiscardedAt!, TimeEvent.occurred))}. '
                            'The record that it existed survives; the images '
                            'do not.',
                    style: const TextStyle(
                      color: AuraSurface.muted,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          for (final evidence in s.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s12),
              child: _EvidenceCard(
                evidence: evidence,
                view: _opened[evidence.id],
                opening: _opening.contains(evidence.id),
                failure: _failed[evidence.id],
                onOpen: () => _open(evidence),
              ),
            ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.evidence,
    required this.view,
    required this.opening,
    required this.failure,
    required this.onOpen,
  });

  final IdentityEvidence evidence;
  final IdentityEvidenceView? view;
  final bool opening;
  final String? failure;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                evidence.kind == IdentityEvidenceKind.governmentId
                    ? Icons.badge_outlined
                    : Icons.face_outlined,
                size: 17,
                color: evidence.discarded
                    ? AuraSurface.faint
                    : AuraSurface.accent,
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text(
                  evidence.kind.label,
                  style: TextStyle(
                    color: evidence.discarded
                        ? AuraSurface.muted
                        : AuraSurface.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (evidence.discarded)
                const OperatorStatePill(state: 'DESTROYED', dense: true)
              else if (view == null && !opening)
                TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    foregroundColor: AuraSurface.accent,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Look at it'),
                )
              else if (opening)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            evidence.kind.purpose,
            style: const TextStyle(
              color: AuraSurface.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              failure!,
              style: const TextStyle(
                color: AuraSurface.dangerInk,
                fontSize: 12,
              ),
            ),
          ],
          if (view != null) ...[
            const SizedBox(height: AuraSpace.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AuraRadius.md),
              child: Image.network(
                view!.url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(AuraSpace.s16),
                  child: Text(
                    'The image could not be displayed. Your having opened it '
                    'is still recorded.',
                    style: TextStyle(
                        color: AuraSurface.dangerInk, fontSize: 12.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
            const Text(
              'Recorded: you opened this.',
              style: TextStyle(color: AuraSurface.faint, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WHAT HAPPENED BEFORE
// ═════════════════════════════════════════════════════════════════════════════

class _History extends StatelessWidget {
  const _History({required this.submission});

  final IdentitySubmission submission;

  @override
  Widget build(BuildContext context) {
    return OperatorSection(
      title: 'What this person asked before',
      subtitle: 'Deciding the same claim two different ways is what this '
          'exists to prevent.',
      child: OperatorPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final prior in submission.history)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        OperatorStatePill(
                          state: prior.state.label,
                          dense: true,
                          tone: prior.state == IdentitySubmissionState.approved
                              ? OperatorTone.good
                              : OperatorTone.neutral,
                        ),
                        const SizedBox(width: AuraSpace.s8),
                        if (prior.reviewedAt != null)
                          Text(
                            AuraTemporal.humanize(ProductTime(
                                prior.reviewedAt!, TimeEvent.occurred)),
                            style: const TextStyle(
                                color: AuraSurface.faint, fontSize: 11.5),
                          ),
                      ],
                    ),
                    if (prior.decisionReason != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        prior.decisionReason!,
                        style: const TextStyle(
                          color: AuraSurface.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// THE DECISION
// ═════════════════════════════════════════════════════════════════════════════

class _Decision extends ConsumerWidget {
  const _Decision({
    required this.submission,
    required this.authority,
    required this.onDecided,
  });

  final IdentitySubmission submission;
  final OperatorAuthority authority;
  final VoidCallback onDecided;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.identityVerificationWrite)) {
      return const OperatorSection(
        title: 'What happens next',
        child: OperatorInsufficientCapability(
          needs: 'identity verification write',
        ),
      );
    }

    if (!submission.awaitsDecision) {
      // ALREADY RESOLVED. The authority refuses a second decision, so the
      // console offers none — and says who decided and why instead.
      return OperatorSection(
        title: 'This was already decided',
        child: OperatorPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                submission.reviewerName == null
                    ? '${submission.state.label}.'
                    : '${submission.state.label} by '
                        '${submission.reviewerName}.',
                style: const TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (submission.reviewedAt != null) ...[
                const SizedBox(height: 3),
                Text(
                  AuraTemporal.humanize(
                    ProductTime(submission.reviewedAt!, TimeEvent.occurred),
                  ),
                  style: const TextStyle(
                      color: AuraSurface.faint, fontSize: 11.5),
                ),
              ],
              if (submission.decisionReason != null) ...[
                const SizedBox(height: AuraSpace.s10),
                Text(
                  submission.decisionReason!,
                  style: const TextStyle(
                    color: AuraSurface.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final missing = submission.missingForApproval;

    return OperatorSection(
      title: 'What happens next',
      subtitle: 'Every decision requires a reason, and the person is told.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (missing.isNotEmpty) ...[
            OperatorPanel(
              tone: OperatorTone.warn,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.gpp_maybe_rounded,
                      size: 16, color: AuraSurface.warnInk),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(
                    child: Text(
                      'This cannot be approved on the evidence present: '
                      '${missing.map((k) => k.label.toLowerCase()).join(' and ')} '
                      '${missing.length == 1 ? 'is' : 'are'} missing. Asking '
                      'for more is the honest move.',
                      style: const TextStyle(
                        color: AuraSurface.muted,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (submission.canApproveOnEvidence)
                _Verdict(
                  label: 'They are who they say',
                  onPressed: () => _decide(context, ref, 'APPROVED'),
                ),
              _Verdict(
                label: 'Ask for more',
                onPressed: () => _decide(context, ref, 'NEEDS_MORE_INFO'),
              ),
              _Verdict(
                label: 'Refuse',
                danger: true,
                onPressed: () => _decide(context, ref, 'REJECTED'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    String decision,
  ) async {
    final person = submission.subject;
    final name = person.displayName.trim().isNotEmpty
        ? person.displayName.trim()
        : (person.handle.trim().isNotEmpty
            ? '@${person.handle.trim()}'
            : person.userId);

    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: switch (decision) {
          'APPROVED' => 'Verify this person’s identity',
          'REJECTED' => 'Refuse this claim',
          _ => 'Ask for more',
        },
        subject: name,
        detail: 'The identity authority records this and applies it. Aura '
            'Admin invokes that authority; it does not decide here.',
        confirmLabel: switch (decision) {
          'APPROVED' => 'Verify',
          'REJECTED' => 'Refuse',
          _ => 'Ask',
        },
        destructive: decision == 'REJECTED',
        requiresReason: true,
        reasonLabel: switch (decision) {
          'APPROVED' => 'What the evidence showed',
          'REJECTED' => 'Why this claim is refused',
          _ => 'What else is needed',
        },
        consequences: [
          if (decision == 'APPROVED')
            const OperatorConsequence(
              text: 'A verified IDENTITY class is granted, and it becomes '
                  'publicly visible on this person.',
              tone: OperatorTone.good,
              icon: Icons.verified_rounded,
            )
          else if (decision == 'REJECTED')
            const OperatorConsequence(
              text: 'The claim is refused. They may try again after a '
                  'cooling-off period — a refusal is never permanent.',
              tone: OperatorTone.danger,
              icon: Icons.block_rounded,
            )
          else
            const OperatorConsequence(
              text: 'They are asked for more. This is not a judgement about '
                  'them, and they may resubmit as often as needed.',
              icon: Icons.help_outline_rounded,
            ),
          const OperatorConsequence(
            text: 'The person is notified.',
            icon: Icons.notifications_active_outlined,
          ),
          if (decision == 'APPROVED')
            const OperatorConsequence(
              text: 'The identity documents are destroyed on schedule '
                  'regardless of this decision.',
              icon: Icons.auto_delete_outlined,
            ),
          OperatorConsequence.recorded('This decision and your reason'),
        ],
        perform: (reason) async {
          await ref.read(operatorIdentityRepositoryProvider).decide(
                submission.id,
                decision: decision,
                reason: reason ?? '',
              );
          return switch (decision) {
            'APPROVED' => 'Verified. The person has been told.',
            'REJECTED' => 'Refused, with your reason. The person has been told.',
            _ => 'Asked. The person has been told what is needed.',
          };
        },
      ),
    );
    if (done) onDecided();
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? AuraSurface.dangerInk : AuraSurface.ink,
        side: const BorderSide(color: AuraSurface.divider),
      ),
      child: Text(label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final OperatorTone? tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(color: AuraSurface.faint, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: tone == null ? AuraSurface.ink : tone!.ink,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _day(DateTime when) =>
    '${when.year}-${when.month.toString().padLeft(2, '0')}-'
    '${when.day.toString().padLeft(2, '0')}';
