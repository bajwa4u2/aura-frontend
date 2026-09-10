import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../institutions/verification/data/institution_verification_repository.dart';
import '../data/institution_verification_review_repository.dart';

/// THE INSTITUTION VERIFICATION QUEUE.
///
/// Until this existed a reviewer could not act on the three-proof system at
/// all: the lifecycle permitted their edges and the writer enforced them, and
/// nothing exposed them. That is the inverse of the rule the founder set — do
/// not build a button whose transition cannot execute — and it is the worse
/// half, because the work simply could not be done.
///
/// WHAT A REVIEWER IS SHOWN, AND WHAT THEY ARE NOT:
///
///   They see the CASE: which institution, which proof, what state, what kind
///   of evidence was relied on, and how long it has waited.
///
///   They do NOT see a verdict suggested to them. There is no "looks fine"
///   affordance and no default-selected outcome. An interface that pre-selects
///   an answer is making the decision the policy reserves for a person.
///
///   A refusal or a request for information cannot be submitted empty, and the
///   floor is a real sentence rather than one character. §2.10 requires a
///   reason; a reason nobody can act on is the dead end wearing a new hat.
class InstitutionVerificationReviewArea extends ConsumerWidget {
  const InstitutionVerificationReviewArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(institutionVerificationQueueProvider);

    return queue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AuraErrorState(
        title: 'The queue could not be loaded',
        // The service's own words where it gave any. A reviewer told "try
        // again" cannot tell a refusal from an outage.
        body: e is InstitutionVerificationException
            ? e.message
            : 'The verification queue could not be loaded.',
        action: AuraSecondaryButton(
          label: 'Try again',
          onPressed: () => ref.invalidate(institutionVerificationQueueProvider),
        ),
      ),
      data: (q) {
        if (q.isEmpty) {
          return const AuraEmptyState(
            title: 'Nothing waiting',
            body: 'No institution verification is currently in review.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AuraSpace.lg),
          children: [
            if (q.existence.isNotEmpty) ...[
              const AuraSectionHeader(title: 'Does the institution exist?'),
              for (final c in q.existence)
                _ExistenceCaseCard(
                  key: ValueKey(c.proofId),
                  item: c,
                  onChanged: () =>
                      ref.invalidate(institutionVerificationQueueProvider),
                ),
              const SizedBox(height: AuraSpace.lg),
            ],
            if (q.authority.isNotEmpty) ...[
              const AuraSectionHeader(title: 'May this person speak for it?'),
              for (final c in q.authority)
                _AuthorityCaseCard(
                  key: ValueKey(c.proofId),
                  item: c,
                  onChanged: () =>
                      ref.invalidate(institutionVerificationQueueProvider),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ExistenceCaseCard extends ConsumerStatefulWidget {
  const _ExistenceCaseCard({super.key, required this.item, required this.onChanged});

  final ExistenceCase item;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ExistenceCaseCard> createState() => _ExistenceCaseCardState();
}

class _ExistenceCaseCardState extends ConsumerState<_ExistenceCaseCard> {
  final _reason = TextEditingController();
  String? _confidence;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final repo = ref.read(institutionVerificationReviewRepositoryProvider);

    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.institutionId, style: AuraText.title),
                ),
                if (item.priority)
                  // §4.3 -- priority is placement, not a different bar. The
                  // badge says why it is near the top, not that it is special.
                  const _Tag(label: 'Needs a person'),
              ],
            ),
            const SizedBox(height: AuraSpace.xs),
            Text('State: ${item.state.name}', style: AuraText.small),
            if (item.category != null)
              Text('Category: ${item.category}', style: AuraText.small),
            if (item.categoryNeedsReview)
              // Honest about the gap. §5.19 asks for a one-time admin pass for
              // anything that did not map cleanly, and this is that prompt.
              const Text(
                'The legacy class did not map cleanly. Decide the category as '
                'part of this review.',
                style: AuraText.small,
              ),
            if (_error != null) ...[
              const SizedBox(height: AuraSpace.sm),
              Text(_error!, style: AuraText.small),
            ],
            const SizedBox(height: AuraSpace.md),
            if (item.state == ExistenceState.submitted ||
                item.state == ExistenceState.automatedCheck)
              AuraSecondaryButton(
                label: 'Take for review',
                onPressed: _busy
                    ? null
                    : () => _run(() => repo.takeExistence(item.proofId)),
              ),
            if (item.state == ExistenceState.manualReview) ...[
              // NO DEFAULT SELECTION. §1.4 makes confirmation carry a stated
              // strength, and pre-selecting one would make the interface
              // decide how strong the evidence was.
              DropdownButtonFormField<String>(
                initialValue: _confidence,
                decoration: const InputDecoration(
                  labelText: 'How strongly is this confirmed?',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'DOMAIN_ONLY',
                    child: Text('Domain only'),
                  ),
                  DropdownMenuItem(
                    value: 'DOCUMENT_REVIEWED',
                    child: Text('Document reviewed'),
                  ),
                  DropdownMenuItem(
                    value: 'REGISTRY_CONFIRMED',
                    child: Text('Confirmed against a register'),
                  ),
                ],
                onChanged: _busy ? null : (v) => setState(() => _confidence = v),
              ),
              const SizedBox(height: AuraSpace.sm),
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason, or what is still needed',
                  helperText:
                      'Required to refuse or to ask for more. At least a sentence.',
                ),
              ),
              const SizedBox(height: AuraSpace.md),
              Wrap(
                spacing: AuraSpace.sm,
                runSpacing: AuraSpace.sm,
                children: [
                  AuraPrimaryButton(
                    label: 'Confirm',
                    onPressed: _busy || _confidence == null
                        ? null
                        : () => _run(() => repo.confirmExistence(
                              item.proofId,
                              _confidence!,
                              reason: _reason.text,
                            )),
                  ),
                  AuraSecondaryButton(
                    label: 'Ask for more',
                    onPressed: _busy || !_reasoned
                        ? null
                        : () => _run(() => repo.requestExistenceInfo(
                              item.proofId,
                              _reason.text.trim(),
                            )),
                  ),
                  AuraSecondaryButton(
                    label: 'Refuse',
                    onPressed: _busy || !_reasoned
                        ? null
                        : () => _run(() => repo.rejectExistence(
                              item.proofId,
                              _reason.text.trim(),
                            )),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A reason nobody can act on is not a reason. Ten characters is the same
  /// floor the server enforces, so the button and the API agree.
  bool get _reasoned => _reason.text.trim().length >= 10;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is InstitutionVerificationException
          ? e.message
          : 'That did not go through. Nothing was decided.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _AuthorityCaseCard extends ConsumerStatefulWidget {
  const _AuthorityCaseCard({super.key, required this.item, required this.onChanged});

  final AuthorityCase item;
  final VoidCallback onChanged;

  @override
  ConsumerState<_AuthorityCaseCard> createState() => _AuthorityCaseCardState();
}

class _AuthorityCaseCardState extends ConsumerState<_AuthorityCaseCard> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _reasoned => _reason.text.trim().length >= 10;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final repo = ref.read(institutionVerificationReviewRepositoryProvider);

    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.institutionId, style: AuraText.title),
            const SizedBox(height: AuraSpace.xs),
            // WHOSE claim. An authority decision is about one person and the
            // reviewer must be able to see which.
            Text('Claimant: ${item.userId}', style: AuraText.small),
            Text('State: ${item.state.name}', style: AuraText.small),
            if (item.evidenceKind != null)
              Text('Relying on: ${item.evidenceKind!.label}', style: AuraText.small),
            if (_error != null) ...[
              const SizedBox(height: AuraSpace.sm),
              Text(_error!, style: AuraText.small),
            ],
            const SizedBox(height: AuraSpace.md),
            if (item.state == AuthorityState.submitted)
              AuraSecondaryButton(
                label: 'Take for review',
                onPressed: _busy
                    ? null
                    : () => _run(() => repo.takeAuthority(item.proofId)),
              ),
            if (item.state == AuthorityState.underReview) ...[
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason, or what is still needed',
                  helperText:
                      'Required to refuse or to ask for more. At least a sentence.',
                ),
              ),
              const SizedBox(height: AuraSpace.md),
              Wrap(
                spacing: AuraSpace.sm,
                runSpacing: AuraSpace.sm,
                children: [
                  AuraPrimaryButton(
                    label: 'Confirm authority',
                    onPressed: _busy
                        ? null
                        : () => _run(() => repo.confirmAuthority(
                              item.proofId,
                              reason: _reason.text,
                            )),
                  ),
                  AuraSecondaryButton(
                    label: 'Ask for more',
                    onPressed: _busy || !_reasoned
                        ? null
                        : () => _run(() => repo.requestAuthorityInfo(
                              item.proofId,
                              _reason.text.trim(),
                            )),
                  ),
                  AuraSecondaryButton(
                    label: 'Refuse',
                    onPressed: _busy || !_reasoned
                        ? null
                        : () => _run(() => repo.rejectAuthority(
                              item.proofId,
                              _reason.text.trim(),
                            )),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is InstitutionVerificationException
          ? e.message
          : 'That did not go through. Nothing was decided.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.sm,
        vertical: AuraSpace.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AuraText.small),
    );
  }
}
