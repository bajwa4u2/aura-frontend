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
                          if (s.evidenceDiscardedAt == null) ...[
                            _DocumentAgeSection(
                              submission: s,
                              canWrite: authority.can(
                                  OperatorCapability.identityVerificationWrite),
                            ),
                            const SizedBox(height: AuraSpace.s20),
                          ],
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
            if (documentKindLabel(submission.documentKind) != null)
              _Row(
                label: 'Document',
                value: documentKindLabel(submission.documentKind)!,
              ),
            if (submission.requiredSides != null &&
                submission.requiredSides!.isNotEmpty)
              _Row(
                label: 'Sides required',
                value: submission.requiredSides!
                    .map((s) => documentSideLabel(s) ?? s)
                    .join(', '),
              ),
            if (submission.documentType != null)
              _Row(label: 'Described as', value: submission.documentType!),
            if (submission.verifiedLegalName != null)
              _Row(label: 'Legal name', value: submission.verifiedLegalName!),
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

  // ELEVATED gates nothing since 2026-09-19: institution authority is a
  // separate, institution-specific review, not a stronger identity.
  static String _tier(String wire) => switch (wire.toUpperCase()) {
        'BASE' => 'Identity verification',
        'ELEVATED' => 'Elevated (historical; no longer required for anything)',
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
                  documentSideLabel(evidence.side) == null
                      ? evidence.kind.label
                      : '${evidence.kind.label} — ${documentSideLabel(evidence.side)}',
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

class _Decision extends ConsumerStatefulWidget {
  const _Decision({
    required this.submission,
    required this.authority,
    required this.onDecided,
  });

  final IdentitySubmission submission;
  final OperatorAuthority authority;
  final VoidCallback onDecided;

  @override
  ConsumerState<_Decision> createState() => _DecisionState();
}

class _DecisionState extends ConsumerState<_Decision> {
  /// THE VERIFIED RESULT (founder, 2026-09-19). The legal name exactly as the
  /// reviewer reads it on the document. It outlives the images, and a later
  /// institution-authority review compares it with the name on a business
  /// document — so it is typed from the document, never copied from the
  /// profile.
  final _legalName = TextEditingController();

  IdentitySubmission get submission => widget.submission;
  OperatorAuthority get authority => widget.authority;
  VoidCallback get onDecided => widget.onDecided;

  @override
  void initState() {
    super.initState();
    _legalName.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _legalName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final missing = submission.missingDescribed;
    final hasName = _legalName.text.trim().isNotEmpty;

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
                      '${missing.join(' and ')} '
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
          if (submission.canApproveOnEvidence) ...[
            TextField(
              controller: _legalName,
              decoration: const InputDecoration(
                labelText: 'Legal name exactly as on the document',
                helperText: 'Required to approve. Kept as the verified result '
                    'after the images are destroyed.',
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
                  onPressed: hasName ? () => _decide(context, ref, 'APPROVED') : null,
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
        subject: decision == 'APPROVED'
            ? '$name — legal name “${_legalName.text.trim()}”'
            : name,
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
                verifiedLegalName:
                    decision == 'APPROVED' ? _legalName.text.trim() : null,
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
  final VoidCallback? onPressed;
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

/// "Age, from the document" (founder, 2026-09-29; drawn and approved:
/// https://claude.ai/artifact/6ouRsnfWrmFLzbgrX5xj2y). Aura reads the date of
/// birth from the document's machine-readable lines or licence barcode on its
/// own server, or the reviewer types it; either way the reviewer is told the
/// age against the publication age where the person lives. Advice only.
class _DocumentAgeSection extends ConsumerStatefulWidget {
  const _DocumentAgeSection({required this.submission, required this.canWrite});

  final IdentitySubmission submission;
  final bool canWrite;

  @override
  ConsumerState<_DocumentAgeSection> createState() => _DocumentAgeSectionState();
}

class _DocumentAgeSectionState extends ConsumerState<_DocumentAgeSection> {
  late DocumentAge _age = widget.submission.documentAge;
  bool _busy = false;
  String? _trouble;
  DateTime? _typed;

  @override
  void initState() {
    super.initState();
    // Read as soon as a reviewer who may write opens it: the advice should be
    // there by the time they reach the decision.
    if (_age.state == 'UNREAD' && widget.canWrite) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _read());
    }
  }

  Future<void> _run(Future<DocumentAge> Function() call) async {
    setState(() {
      _busy = true;
      _trouble = null;
    });
    try {
      final next = await call();
      if (mounted) setState(() => _age = next);
    } catch (_) {
      if (mounted) {
        setState(() => _trouble = 'Aura could not do that just now. Nothing was recorded.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _read() => _run(() => ref
      .read(operatorIdentityRepositoryProvider)
      .readDocumentAge(widget.submission.id));

  Future<void> _check() async {
    final d = _typed;
    if (d == null) return;
    final ymd = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await _run(() => ref
        .read(operatorIdentityRepositoryProvider)
        .typeDocumentDob(widget.submission.id, ymd));
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// A date of birth is a calendar date, not a moment: no time is shown.
  static String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String _where(String? bucket) => switch (bucket) {
        'US' => 'United States',
        'EU_EEA' => 'EU / EEA',
        _ => 'rest of the world',
      };

  String _from() {
    final kind = switch (widget.submission.documentKind) {
      'PASSPORT' => 'Passport',
      'DRIVING_LICENCE' => 'Driving licence',
      'IDENTITY_CARD' => 'Identity card',
      'RESIDENCE_PERMIT' => 'Residence permit',
      _ => 'Document',
    };
    return switch (_age.source) {
      'MRZ' => '$kind, machine-readable lines · check digits correct',
      'BARCODE' => '$kind, barcode',
      _ => 'Typed by a reviewer from the document',
    };
  }

  Widget _verdict(String text, Color bg, Color ink) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s10,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AuraRadius.r10),
        ),
        child: Text(
          text,
          style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final a = _age;
    final children = <Widget>[];

    if (_busy && !a.isRead) {
      children.add(const Text(
        'Reading the document on Aura’s own server…',
        style: TextStyle(color: AuraSurface.muted, fontSize: 13),
      ));
    } else if (a.isRead) {
      final under = a.oldEnoughToPublish == false;
      final differs = a.declaredMatches == false;
      children.add(under
          ? _verdict(
              'Under the publication age where they live: ${a.age}, the limit is ${a.publicationAge}',
              AuraSurface.dangerBg,
              AuraSurface.dangerInk)
          : differs
              ? _verdict(
                  'Old enough, but the document’s date of birth is not the one they gave',
                  AuraSurface.warnBg,
                  AuraSurface.warnInk)
              : _verdict('Old enough to publish where they live', AuraSurface.goodBg,
                  AuraSurface.goodInk));
      children.add(const SizedBox(height: AuraSpace.s10));
      children.addAll([
        _Row(label: 'Read from', value: _from()),
        _Row(label: 'Date of birth on the document', value: _day(a.documentDateOfBirth!)),
        _Row(label: 'Age today', value: '${a.age}'),
        _Row(
          label: 'Publication age where they live',
          value: '${a.publicationAge} · ${_where(a.bucket)}',
        ),
        _Row(
          label: 'Date of birth they gave Aura',
          value: a.declaredDateOfBirth == null
              ? 'Not given'
              : '${_day(a.declaredDateOfBirth!)} · '
                  '${a.declaredMatches == true ? 'matches' : a.differsByYears != null ? 'differs by ${a.differsByYears} year${a.differsByYears == 1 ? '' : 's'}' : 'differs'}',
          tone: differs ? OperatorTone.pending : null,
        ),
      ]);
      if (under) {
        children.add(const Padding(
          padding: EdgeInsets.only(top: AuraSpace.s4),
          child: Text(
            'Aura already refuses publishing to anyone under the limit by the date they gave; '
            'here the document is what says so.',
            style: TextStyle(color: AuraSurface.faint, fontSize: 11.5),
          ),
        ));
      }
    } else if (a.state == 'UNREAD' && widget.canWrite) {
      // Never an empty panel: before the read runs, or if it could not.
      children.addAll([
        const Text(
          'Not read yet. Aura reads the document’s machine-readable lines or barcode on its own server.',
          style: TextStyle(color: AuraSurface.muted, fontSize: 13),
        ),
        const SizedBox(height: AuraSpace.s8),
        TextButton(
          onPressed: _read,
          style: TextButton.styleFrom(foregroundColor: AuraSurface.accent),
          child: const Text('Read the document'),
        ),
      ]);
    } else if (a.state == 'UNREADABLE' || (!widget.canWrite && a.state == 'UNREAD')) {
      children.add(_verdict(
        a.state == 'UNREADABLE'
            ? 'This document has no machine-readable lines or barcode Aura could read.'
            : 'Not read yet. A reviewer who may decide can read it.',
        AuraSurface.warnBg,
        AuraSurface.warnInk,
      ));
      if (widget.canWrite) {
        children.addAll([
          const SizedBox(height: AuraSpace.s10),
          const Text(
            'Choose the date of birth exactly as the document shows it, and Aura will check the age.',
            style: TextStyle(color: AuraSurface.ink, fontSize: 13),
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _typed ?? DateTime(now.year - 30),
                          firstDate: DateTime(1900),
                          lastDate: now,
                          helpText: 'Date of birth on the document',
                        );
                        if (picked != null) setState(() => _typed = picked);
                      },
                child: Text(_typed == null ? 'Date of birth on the document' : _day(_typed!)),
              ),
              TextButton(
                onPressed: _busy || _typed == null ? null : _check,
                style: TextButton.styleFrom(foregroundColor: AuraSurface.accent),
                child: const Text('Check the age'),
              ),
              TextButton(
                onPressed: _busy ? null : _read,
                child: const Text('Try reading again'),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          const Text(
            'Recorded as chosen by you, with the time. Kept with the review; destroyed with the evidence.',
            style: TextStyle(color: AuraSurface.faint, fontSize: 11.5),
          ),
        ]);
      }
    }
    if (_trouble != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: AuraSpace.s8),
        child: Text(_trouble!, style: const TextStyle(color: AuraSurface.dangerInk, fontSize: 12.5)),
      ));
    }

    return OperatorSection(
      title: 'Age, from the document',
      subtitle: 'Advice for your decision. It decides nothing and blocks nothing.',
      child: OperatorPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
