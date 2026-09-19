import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/product/temporal.dart';
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
///   An AUTHORITY claim is shown beside the verified person it belongs to —
///   verified legal name, identity status and expiry — and beside the
///   institution and every document supplied (founder, 2026-09-19), so the
///   reviewer can match the name on a business document to the verified
///   person before confirming anything.
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
      loading: () => const AuraProductState(state: ProductState.loading),
      // C0 — say what is TRUE and let the state authority decide how that
      // looks and whether retry is an honest offer.
      error: (e, _) => AuraProductState(
        state: ProductState.retryableError,
        headline: 'The queue could not be loaded',
        // The service's own words where it gave any. A reviewer told only to
        // try again cannot tell a refusal from an outage.
        detail: e is InstitutionVerificationException ? e.message : null,
        action: AuraSecondaryButton(
          label: ProductLabels.of(ProductAction.retry),
          onPressed: () => ref.invalidate(institutionVerificationQueueProvider),
          icon: Icons.refresh_rounded,
        ),
      ),
      data: (q) {
        if (q.isEmpty) {
          return const AuraProductState(
            state: ProductState.empty,
            headline: 'Nothing waiting',
            detail: 'No institution verification is currently in review.',
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
                maxLines: null,
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

  /// How strongly the institution itself is confirmed, when it is decided
  /// from this same claim. DOCUMENT_REVIEWED is where a reviewer who has just
  /// read a registration document would land; they can change it.
  String _existenceConfidence = 'DOCUMENT_REVIEWED';

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
    final detailAsync = ref.watch(authorityClaimDetailProvider(item.proofId));
    final detail = detailAsync.valueOrNull;

    // NOBODY DECIDES THEIR OWN AUTHORITY. The server refuses it; the console
    // does not offer it, and says why.
    final selfReview = detail?.reviewerIsClaimant ?? false;

    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail?.institutionName ?? item.institutionId, style: AuraText.title),
            const SizedBox(height: AuraSpace.xs),
            Text('State: ${item.state.name}', style: AuraText.small),
            if (item.evidenceKind != null)
              Text('Relying on: ${item.evidenceKind!.label}', style: AuraText.small),
            const SizedBox(height: AuraSpace.md),
            detailAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text(
                e is InstitutionVerificationException
                    ? e.message
                    : 'The claim could not be read. Nothing was decided.',
                style: AuraText.small,
              ),
              data: (d) => _AuthorityComparison(detail: d),
            ),
            if (_error != null) ...[
              const SizedBox(height: AuraSpace.sm),
              Text(_error!, style: AuraText.small),
            ],
            const SizedBox(height: AuraSpace.md),
            if (selfReview)
              const Text(
                'This is your own claim. Another reviewer must decide it — you '
                'cannot review your own institution authority.',
                style: AuraText.body,
              )
            else ...[
              if (detail != null) ..._existenceActions(detail, repo),
              if (item.state == AuthorityState.submitted)
                AuraSecondaryButton(
                  label: 'Take for review',
                  onPressed: _busy
                      ? null
                      : () => _run(() => repo.takeAuthority(item.proofId)),
                ),
              if (item.state == AuthorityState.underReview) ...[
                if (detail != null && !detail.identityVerified)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AuraSpace.sm),
                    child: Text(
                      'This person has no current identity verification, so '
                      'their authority cannot be confirmed yet.',
                      style: AuraText.body,
                    ),
                  ),
                TextField(
                  controller: _reason,
                  minLines: 2,
                  maxLines: null,
                  onChanged: (_) => setState(() {}),
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
                      onPressed: _busy || (detail != null && !detail.identityVerified)
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
          ],
        ),
      ),
    );
  }

  /// THE INSTITUTION, DECIDED FROM THE SAME CLAIM when one document was sent
  /// for both questions. The two are still decided separately — confirming
  /// the institution exists says nothing about this person's authority.
  List<Widget> _existenceActions(
    AuthorityClaimDetail d,
    InstitutionVerificationReviewRepository repo,
  ) {
    final proofId = d.existenceProofId;
    final state = d.existenceState;
    if (proofId == null || state == null) return const [];
    if (state == ExistenceState.submitted || state == ExistenceState.automatedCheck) {
      return [
        AuraSecondaryButton(
          label: 'Take the institution for review too',
          onPressed: _busy ? null : () => _run(() => repo.takeExistence(proofId)),
        ),
        const SizedBox(height: AuraSpace.md),
      ];
    }
    if (state != ExistenceState.manualReview) return const [];
    return [
      const Text('Does the institution exist?', style: AuraText.body),
      const SizedBox(height: AuraSpace.xs),
      DropdownButtonFormField<String>(
        initialValue: _existenceConfidence,
        decoration: const InputDecoration(labelText: 'How strongly is this confirmed?'),
        items: const [
          DropdownMenuItem(value: 'DOMAIN_ONLY', child: Text('Domain only')),
          DropdownMenuItem(value: 'DOCUMENT_REVIEWED', child: Text('Document reviewed')),
          DropdownMenuItem(
            value: 'REGISTRY_CONFIRMED',
            child: Text('Confirmed against a register'),
          ),
        ],
        onChanged: _busy
            ? null
            : (v) => setState(() => _existenceConfidence = v ?? 'DOCUMENT_REVIEWED'),
      ),
      const SizedBox(height: AuraSpace.sm),
      AuraSecondaryButton(
        label: 'Confirm the institution exists',
        onPressed: _busy
            ? null
            : () => _run(() => repo.confirmExistence(proofId, _existenceConfidence)),
      ),
      const SizedBox(height: AuraSpace.md),
    ];
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(authorityClaimDetailProvider(widget.item.proofId));
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

/// THE VERIFIED PERSON, THE INSTITUTION, AND THE EVIDENCE — side by side.
///
/// The three things a reviewer must be able to say before confirming: this
/// is the already-verified person, this is the institution, and the evidence
/// names that person in the role they claim.
class _AuthorityComparison extends ConsumerStatefulWidget {
  const _AuthorityComparison({required this.detail});

  final AuthorityClaimDetail detail;

  @override
  ConsumerState<_AuthorityComparison> createState() => _AuthorityComparisonState();
}

class _AuthorityComparisonState extends ConsumerState<_AuthorityComparison> {
  final Set<String> _opening = {};
  final Map<String, String> _failed = {};

  Future<void> _open(AuthorityClaimEvidence e) async {
    setState(() {
      _opening.add(e.id);
      _failed.remove(e.id);
    });
    try {
      final url = await ref
          .read(institutionVerificationReviewRepositoryProvider)
          .openEvidence(e.id);
      // Opened in the platform viewer, which reads PDFs and images alike. The
      // signed URL is short-lived and never stored or copied anywhere.
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      if (!launched && mounted) {
        setState(() => _failed[e.id] =
            'It could not be displayed here. Your opening it is still recorded.');
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _failed[e.id] = err is InstitutionVerificationException
          ? err.message
          : 'This could not be opened. Nothing was recorded as seen.');
    } finally {
      if (mounted) setState(() => _opening.remove(e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    String day(DateTime when) =>
        AuraTemporal.calendar(ProductTime(when, TimeEvent.occurred));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('The verified person', style: AuraText.subtitle),
        const SizedBox(height: AuraSpace.xs),
        _Fact('Verified legal name',
            d.verifiedLegalName ??
                (d.identityVerified
                    ? 'Not recorded (verified before legal names were kept)'
                    : '—')),
        _Fact('Identity', d.identityVerified ? 'Verified' : 'Not verified'),
        if (d.identityDocument != null) _Fact('Document', d.identityDocument!),
        if (d.identityVerifiedAt != null) _Fact('Verified on', day(d.identityVerifiedAt!)),
        if (d.identityExpiresAt != null) _Fact('Valid until', day(d.identityExpiresAt!)),
        _Fact(
          'Account',
          [d.claimantName, if (d.claimantHandle != null) '@${d.claimantHandle}']
              .whereType<String>()
              .join(' · '),
        ),
        const SizedBox(height: AuraSpace.md),
        const Text('The institution', style: AuraText.subtitle),
        const SizedBox(height: AuraSpace.xs),
        _Fact('Name', d.institutionName ?? d.institutionId),
        if (d.institutionDomain != null) _Fact('Domain', d.institutionDomain!),
        if (d.institutionWebsite != null) _Fact('Website', d.institutionWebsite!),
        if (d.institutionJurisdiction != null)
          _Fact('Jurisdiction', d.institutionJurisdiction!),
        if (d.existenceCategory != null) _Fact('Category', d.existenceCategory!),
        _Fact(
          'Exists?',
          d.existenceState == null
              ? 'Not started'
              : d.existenceState == ExistenceState.confirmed
                  ? (d.existenceConfidence?.label ?? 'Confirmed')
                  : d.existenceState!.name,
        ),
        const SizedBox(height: AuraSpace.md),
        const Text('The claim', style: AuraText.subtitle),
        const SizedBox(height: AuraSpace.xs),
        _Fact('Role claimed', d.claimedRole ?? 'Not stated'),
        if (d.claimedRelationship != null) _Fact('Relationship', d.claimedRelationship!),
        if (d.evidenceKind != null) _Fact('Relying on', d.evidenceKind!.label),
        if (d.infoRequested != null) _Fact('Asked for', d.infoRequested!),
        const SizedBox(height: AuraSpace.md),
        const Text('The evidence', style: AuraText.subtitle),
        const SizedBox(height: AuraSpace.xs),
        if (d.evidence.isEmpty)
          const Text('Nothing has been supplied.', style: AuraText.small)
        else
          for (final e in d.evidence)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                e.hasFile
                    ? (e.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined)
                    : Icons.tag_rounded,
              ),
              title: Text(
                e.hasFile ? (e.fileName ?? 'Document') : (e.reference ?? 'Reference'),
                style: AuraText.body,
              ),
              subtitle: Text(
                [
                  e.forAuthority ? 'For authority' : 'For the institution existing',
                  if (!e.submittedByClaimant) 'supplied by someone else',
                  if (e.superseded) 'superseded',
                  if (e.discarded) 'destroyed',
                  if (_failed[e.id] != null) _failed[e.id]!,
                ].join(' · '),
                style: AuraText.small,
              ),
              trailing: !e.hasFile || e.discarded
                  ? null
                  : _opening.contains(e.id)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => _open(e),
                          child: const Text('Open'),
                        ),
            ),
        if (d.evidence.any((e) => e.hasFile))
          const Text(
            'Opening a document is recorded against your name.',
            style: AuraText.small,
          ),
        if (d.transitions.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.md),
          const Text('History', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.xs),
          for (final t in d.transitions)
            Text(
              '${t.at == null ? '' : '${day(t.at!)} · '}${t.fromState} → ${t.toState}'
              ' (${t.actor.toLowerCase()})${t.reason == null ? '' : ' — ${t.reason}'}',
              style: AuraText.small,
            ),
        ],
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: AuraText.small)),
          Expanded(child: Text(value, style: AuraText.body)),
        ],
      ),
    );
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
