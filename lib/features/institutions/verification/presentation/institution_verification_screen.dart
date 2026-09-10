import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/attachments/aura_media_upload.dart';
import '../../../../core/media/media_acquisition.dart';
import '../../../../core/net/dio_provider.dart';
import '../../../../core/product/product_language.dart';
import '../../../../core/product/product_state.dart';
import '../../../../core/product/product_state_view.dart';
import '../../../../core/product/temporal.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_scaffold.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../data/institution_verification_repository.dart';

/// VERIFYING AN INSTITUTION — the owner's side of the governed lifecycle.
///
/// Before this screen existed there was no way in at all. An institution that
/// already existed could not start or resume its verification: the only
/// non-admin entries were a public request that throws for an organisation
/// that already exists, and a claim request. NEEDS_INFO was a state a reviewer
/// could put somebody into and nobody could get them out of.
///
/// THREE THINGS THIS SCREEN REFUSES TO DO, each of which would be easier:
///
///   IT DOES NOT COLLAPSE THE PROOFS. The institution existing and this person
///   being allowed to speak for it are separate facts with separate lifecycles,
///   and the policy says so in as many words. One badge or one progress bar
///   would destroy the distinction that makes the model worth having — an
///   institution can be confirmed while the person looking at the screen has no
///   authority at all, and that is not a partial result, it is two answers.
///
///   IT DOES NOT DECIDE WHAT YOU MAY DO. Every action is rendered from the
///   server's own `available` projection, which comes from the frozen
///   transition table. The founder's rule is that a button may exist only where
///   an edge does; reading the state and inferring the buttons would make that
///   a coincidence rather than a property.
///
///   IT DOES NOT REWORD A REFUSAL. The server's refusals are written for the
///   person who hit them. This release already lost one reason to two correct
///   mappers in series, where a specific sentence became "Please try again".
class InstitutionVerificationScreen extends ConsumerStatefulWidget {
  const InstitutionVerificationScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<InstitutionVerificationScreen> createState() =>
      _InstitutionVerificationScreenState();
}

/// One document or reference the person has offered but not yet submitted.
class _Staged {
  _Staged({required this.label, this.reference});

  final String label;
  String? mediaId;
  String? reference;
  bool uploading = false;
  String? failure;

  bool get ready => mediaId != null || (reference?.trim().isNotEmpty ?? false);
}

class _InstitutionVerificationScreenState
    extends ConsumerState<InstitutionVerificationScreen> {
  final List<_Staged> _existenceEvidence = [];
  final List<_Staged> _authorityEvidence = [];

  AuthorityEvidenceKind? _chosenKind;
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final standing = ref.watch(
      institutionVerificationStandingProvider(widget.institutionId),
    );

    return AuraScaffold(
      title: 'Verification',
      body: standing.when(
        loading: () => const AuraProductState(state: ProductState.loading),
        // A failure to LOAD is not a failure of the verification, so this is
        // retryable and says so. C0 — state what is true and let the authority
        // decide what that looks like.
        error: (e, _) => AuraProductState(
          state: ProductState.retryableError,
          headline: 'We could not load this verification',
          detail: e is InstitutionVerificationException ? e.message : null,
          action: AuraSecondaryButton(
            label: ProductLabels.of(ProductAction.retry),
            onPressed: () => ref.invalidate(
              institutionVerificationStandingProvider(widget.institutionId),
            ),
            icon: Icons.refresh_rounded,
          ),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(InstitutionVerificationStanding s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AuraSpace.lg),
      child: Center(
        child: ConstrainedBox(
          // Narrow layouts get the same content, not a reduced one. A person
          // completing this on a phone is the common case, not the exception.
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                _Banner(message: _error!, tone: _Tone.problem),
                const SizedBox(height: AuraSpace.md),
              ],
              _ProofCard(
                title: 'Does this institution exist?',
                // The vocabulary a reviewer uses, in words a person reads.
                standingLabel: _existenceLabel(s),
                tone: _existenceTone(s.existence.state),
                detail: _existenceDetail(s),
                infoRequested: s.existence.infoRequested,
                child: _existenceActions(s),
              ),
              const SizedBox(height: AuraSpace.lg),
              _ProofCard(
                title: 'May you speak for it?',
                standingLabel: _authorityLabel(s.authority.state),
                tone: _authorityTone(s.authority.state),
                detail: _authorityDetail(s),
                infoRequested: s.authority.infoRequested,
                child: _authorityActions(s),
              ),
              if (s.migration.running) ...[
                const SizedBox(height: AuraSpace.lg),
                _MigrationCard(posture: s.migration),
              ],
              const SizedBox(height: AuraSpace.lg),
              const _SeparateProofsNote(),
            ],
          ),
        ),
      ),
    );
  }

  /// TONE IS NOT A VERDICT.
  ///
  /// An unknown state reads as WAITING, never as good or bad. A build that
  /// coloured a string it had never seen would eventually tell somebody they
  /// were verified, or refused, on the strength of a guess.
  _Tone _existenceTone(ExistenceState state) {
    switch (state) {
      case ExistenceState.confirmed:
        return _Tone.good;
      case ExistenceState.rejected:
        return _Tone.problem;
      case ExistenceState.needsInfo:
        return _Tone.waiting;
      case ExistenceState.notStarted:
        return _Tone.neutral;
      case ExistenceState.submitted:
      case ExistenceState.automatedCheck:
      case ExistenceState.manualReview:
      case ExistenceState.unknown:
        return _Tone.waiting;
    }
  }

  _Tone _authorityTone(AuthorityState state) {
    switch (state) {
      case AuthorityState.confirmed:
        return _Tone.good;
      case AuthorityState.rejected:
      case AuthorityState.revoked:
        return _Tone.problem;
      // SUSPENDED is a pause, not a severance, and LEGACY_UNVERIFIED still
      // works today. Colouring either as a problem would tell somebody they
      // had lost something they have not.
      case AuthorityState.suspended:
      case AuthorityState.legacyUnverified:
      case AuthorityState.needsInfo:
        return _Tone.waiting;
      case AuthorityState.notStarted:
        return _Tone.neutral;
      case AuthorityState.submitted:
      case AuthorityState.underReview:
      case AuthorityState.unknown:
        return _Tone.waiting;
    }
  }

  // ── Proof 2 ───────────────────────────────────────────────────────────────

  String _existenceLabel(InstitutionVerificationStanding s) {
    switch (s.existence.state) {
      case ExistenceState.notStarted:
        return 'Not started';
      case ExistenceState.submitted:
      case ExistenceState.automatedCheck:
        return 'With us';
      case ExistenceState.manualReview:
        return 'Being reviewed by a person';
      case ExistenceState.confirmed:
        // §1.4 — graduated, and stated as what was checked rather than as a
        // shortfall. DOMAIN_ONLY is a legitimate permanent destination.
        return s.existenceConfidence?.label ?? 'Confirmed';
      case ExistenceState.rejected:
        return 'Not confirmed';
      case ExistenceState.needsInfo:
        return 'We need something more';
      case ExistenceState.unknown:
        // Never presented as a decision in either direction.
        return 'In review';
    }
  }

  String _existenceDetail(InstitutionVerificationStanding s) {
    if (s.existence.state == ExistenceState.notStarted) {
      return 'Tell us what kind of organisation this is, and what you can show '
          'us about it.';
    }
    if (s.requirementNotEnumerated && s.existence.acceptsEvidence) {
      // Honest about a gap rather than presenting an empty list as guidance.
      return 'Someone will review this by hand. Send whatever best shows the '
          'organisation is real — there is no fixed list for this category.';
    }
    if (s.accepted.isNotEmpty && s.existence.acceptsEvidence) {
      return 'Any of these will do: ${s.accepted.join(' · ')}';
    }
    if (s.requiresManualReview &&
        (s.existence.state == ExistenceState.submitted ||
            s.existence.state == ExistenceState.automatedCheck)) {
      // The wait is explained rather than experienced as a stall.
      return 'This kind of organisation always gets a person to look at it, '
          'whatever our automatic checks find.';
    }
    return '';
  }

  Widget _existenceActions(InstitutionVerificationStanding s) {
    // RENDERED FROM THE SERVER'S PROJECTION, never from the state. A button
    // exists here only where the transition table has an edge.
    final canSubmit = s.existence.canSubmit('SUBMITTED');
    if (!canSubmit && !s.existence.acceptsEvidence) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.existence.state == ExistenceState.notStarted)
          _StartRow(
            busy: _busy,
            onStart: (category) => _guard(() async {
              await ref
                  .read(institutionVerificationRepositoryProvider)
                  .start(widget.institutionId, category);
            }),
          ),
        if (s.existence.acceptsEvidence) ...[
          const SizedBox(height: AuraSpace.md),
          _EvidenceList(
            staged: _existenceEvidence,
            onAddDocument: () => _addDocument(_existenceEvidence),
            onAddReference: (value) => _addReference(_existenceEvidence, value),
            onRemove: (item) => setState(() => _existenceEvidence.remove(item)),
            onRetry: (item) => _retry(item),
          ),
        ],
        if (canSubmit) ...[
          const SizedBox(height: AuraSpace.md),
          AuraPrimaryButton(
            label: s.existence.state == ExistenceState.needsInfo
                ? 'Send this back for review'
                : 'Submit for review',
            onPressed: _busy || !_anyReady(_existenceEvidence)
                ? null
                : () => _guard(() async {
                      await ref
                          .read(institutionVerificationRepositoryProvider)
                          .submitExistence(
                            widget.institutionId,
                            _existenceEvidence
                                .where((e) => e.ready)
                                .map((e) => SuppliedEvidence(
                                      mediaId: e.mediaId,
                                      reference: e.reference,
                                    ))
                                .toList(),
                          );
                      _existenceEvidence.clear();
                    }),
          ),
        ],
      ],
    );
  }

  // ── Proof 3 ───────────────────────────────────────────────────────────────

  String _authorityLabel(AuthorityState state) {
    switch (state) {
      case AuthorityState.notStarted:
        return 'Not started';
      case AuthorityState.submitted:
        return 'With us';
      case AuthorityState.underReview:
        return 'Being reviewed by a person';
      case AuthorityState.needsInfo:
        return 'We need something more';
      case AuthorityState.confirmed:
        return 'You can represent it';
      case AuthorityState.rejected:
        return 'Not confirmed';
      case AuthorityState.legacyUnverified:
        // NEVER shown as verified. §5.19 — "a distinct, honestly-labeled
        // state, never folded into any newly-defined evidenced category."
        return 'Carried over, not yet evidenced';
      case AuthorityState.suspended:
        // Reversible, and the wording says so.
        return 'On hold';
      case AuthorityState.revoked:
        return 'Withdrawn';
      case AuthorityState.unknown:
        return 'In review';
    }
  }

  String _authorityDetail(InstitutionVerificationStanding s) {
    switch (s.authority.state) {
      case AuthorityState.legacyUnverified:
        return 'Your role here came across from the old system. It still works '
            'today, and it has not been checked against the current standard '
            'yet. Sending evidence below is what completes it.';
      case AuthorityState.suspended:
        return 'This is a pause, not a removal. Your role and your history are '
            'untouched.';
      case AuthorityState.confirmed:
        return 'This is about your authority only. Whether the institution '
            'itself is confirmed is the separate question above.';
      default:
        if (s.authority.acceptsEvidence) {
          return 'Any ONE of these is enough.';
        }
        return '';
    }
  }

  Widget _authorityActions(InstitutionVerificationStanding s) {
    final canSubmit = s.authority.canSubmit('SUBMITTED');
    if (!canSubmit && !s.authority.acceptsEvidence) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.authority.acceptsEvidence && s.menu.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.sm),
          // THE WHOLE MENU, always. §2.7 says any one item suffices; a
          // dropdown showing only a suggested item would turn an advisory
          // mapping into a requirement -- a policy change made by a form.
          ...s.menu.map(
            (kind) => RadioListTile<AuthorityEvidenceKind>(
              value: kind,
              groupValue: _chosenKind,
              onChanged: _busy ? null : (v) => setState(() => _chosenKind = v),
              title: Text(kind.label, style: AuraText.body),
              dense: true,
            ),
          ),
          const SizedBox(height: AuraSpace.sm),
          _EvidenceList(
            staged: _authorityEvidence,
            onAddDocument: () => _addDocument(_authorityEvidence),
            onAddReference: (value) => _addReference(_authorityEvidence, value),
            onRemove: (item) => setState(() => _authorityEvidence.remove(item)),
            onRetry: (item) => _retry(item),
          ),
        ],
        if (canSubmit) ...[
          const SizedBox(height: AuraSpace.md),
          AuraPrimaryButton(
            label: s.authority.state == AuthorityState.needsInfo
                ? 'Send this back for review'
                : 'Submit for review',
            onPressed: _busy ||
                    _chosenKind == null ||
                    !_anyReady(_authorityEvidence)
                ? null
                : () => _guard(() async {
                      await ref
                          .read(institutionVerificationRepositoryProvider)
                          .submitAuthority(
                            widget.institutionId,
                            evidenceKind: _chosenKind!,
                            evidence: _authorityEvidence
                                .where((e) => e.ready)
                                .map((e) => SuppliedEvidence(
                                      mediaId: e.mediaId,
                                      reference: e.reference,
                                    ))
                                .toList(),
                          );
                      _authorityEvidence.clear();
                      _chosenKind = null;
                    }),
          ),
        ],
      ],
    );
  }

  // ── evidence acquisition ──────────────────────────────────────────────────

  bool _anyReady(List<_Staged> items) => items.any((e) => e.ready);

  Future<void> _addDocument(List<_Staged> into) async {
    // No `imageQuality` downscale: a re-encoded document can lose exactly the
    // small print a reviewer needs, and an unreadable one costs a whole
    // NEEDS_INFO round trip.
    final resolution = await acquireSingleImage();
    if (!mounted) return;

    // `null` means CANCELLED and nothing else. Every failure path returns a
    // rejection carrying a reason, so silence here can only be a person
    // changing their mind -- and changing your mind is not an error.
    if (resolution == null) return;

    final attachment = resolution.attachment;
    if (attachment == null) {
      setState(() => _error = resolution.rejectionMessage ??
          'That file could not be added. Try another.');
      return;
    }
    final bytes = attachment.bytes;
    if (bytes == null) {
      setState(() => _error = 'That file could not be read. Try another.');
      return;
    }

    // `attachment.fileName`, NOT `attachment.name` -- the latter does not
    // exist, and reaching it through a `dynamic` is what made the identity
    // picker throw on every successful pick while the screen showed nothing.
    final staged = _Staged(label: attachment.fileName ?? 'Document');
    setState(() {
      into.add(staged);
      _error = null;
      staged.uploading = true;
    });

    await _upload(staged, bytes, attachment.mimeType ?? 'image/jpeg');
  }

  Future<void> _upload(_Staged staged, dynamic bytes, String mimeType) async {
    try {
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: bytes,
        fileName: staged.label,
        mimeType: mimeType,
        kind: 'IMAGE',
        source: 'UPLOAD',
      );
      if (!mounted) return;
      setState(() {
        staged.mediaId = result.mediaId;
        staged.uploading = false;
        staged.failure = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Kept in the list WITH a retry, not silently dropped. A person on a
      // phone whose upload failed has not changed their mind.
      setState(() {
        staged.uploading = false;
        staged.failure = 'That did not upload. Tap to try again.';
      });
    }
  }

  Future<void> _retry(_Staged staged) async {
    setState(() {
      staged.failure = null;
      staged.uploading = true;
    });
    // Re-picking is the honest retry: the bytes are not held after a failure,
    // and pretending otherwise would produce a button that cannot work.
    final resolution = await acquireSingleImage();
    if (!mounted) return;
    final attachment = resolution?.attachment;
    final bytes = attachment?.bytes;
    if (bytes == null) {
      setState(() {
        staged.uploading = false;
        staged.failure = 'That did not upload. Tap to try again.';
      });
      return;
    }
    await _upload(staged, bytes, attachment?.mimeType ?? 'image/jpeg');
  }

  void _addReference(List<_Staged> into, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      into.add(_Staged(label: trimmed, reference: trimmed));
      _error = null;
    });
  }

  /// One place that runs a mutation, clears the error, and refreshes.
  Future<void> _guard(Future<void> Function() run) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await run();
      if (!mounted) return;
      ref.invalidate(
        institutionVerificationStandingProvider(widget.institutionId),
      );
    } catch (e) {
      if (!mounted) return;
      // The server's own words. Not re-mapped, not generalised.
      setState(() => _error = e is InstitutionVerificationException
          ? e.message
          : 'That did not go through. Nothing was lost — try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── presentation pieces ─────────────────────────────────────────────────────

enum _Tone { neutral, waiting, good, problem }

class _ProofCard extends StatelessWidget {
  const _ProofCard({
    required this.title,
    required this.standingLabel,
    required this.tone,
    required this.detail,
    required this.infoRequested,
    required this.child,
  });

  final String title;
  final String standingLabel;
  final _Tone tone;
  final String detail;
  final String? infoRequested;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AuraText.title),
            const SizedBox(height: AuraSpace.xs),
            _StandingChip(label: standingLabel, tone: tone),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.sm),
              Text(detail, style: AuraText.body),
            ],
            if (infoRequested != null && infoRequested!.trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.md),
              // WHAT WAS ACTUALLY ASKED FOR, verbatim and prominent. This is
              // the field that stops NEEDS_INFO being a dead end, and burying
              // it would put the dead end back.
              _Banner(message: infoRequested!, tone: _Tone.waiting),
            ],
            const SizedBox(height: AuraSpace.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _StandingChip extends StatelessWidget {
  const _StandingChip({required this.label, required this.tone});

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = switch (tone) {
      _Tone.good => scheme.primary,
      _Tone.problem => scheme.error,
      _Tone.waiting => scheme.tertiary,
      _Tone.neutral => scheme.outline,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        // Read as a standing, not as a stray word, by a screen reader.
        label: 'Current standing: $label',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.sm,
            vertical: AuraSpace.xs,
          ),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
          ),
          child: Text(label, style: AuraText.small),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.tone});

  final String message;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = tone == _Tone.problem ? scheme.error : scheme.tertiary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AuraRadius.sm),
      ),
      child: Text(message, style: AuraText.body),
    );
  }
}

class _SeparateProofsNote extends StatelessWidget {
  const _SeparateProofsNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'These are two separate questions and they are answered separately. Your '
      'own identity verification is a third, kept apart from both.',
      style: AuraText.small,
    );
  }
}


/// The closed taxonomy, offered as a choice rather than a free-text box.
/// §1.1 — "expandable later only by deliberate decision, never open/free-text".
class _StartRow extends StatefulWidget {
  const _StartRow({required this.busy, required this.onStart});

  final bool busy;
  final void Function(String category) onStart;

  @override
  State<_StartRow> createState() => _StartRowState();
}

class _StartRowState extends State<_StartRow> {
  static const _categories = <String, String>{
    'GOVERNMENT_CIVIC': 'Government or civic body',
    'EDUCATIONAL': 'School, college or university',
    'NONPROFIT_COMMUNITY': 'Nonprofit or community organisation',
    'RELIGIOUS': 'Religious organisation',
    'CORPORATE_BUSINESS': 'Company or business',
    'MEDIA': 'Media or journalism',
    'HEALTHCARE': 'Healthcare provider',
  };

  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selected,
          decoration: const InputDecoration(
            // A label AND a hint would hide the hint on Material. Asked as a
            // question so the field explains itself without one.
            labelText: 'What kind of organisation is this?',
          ),
          items: _categories.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: widget.busy ? null : (v) => setState(() => _selected = v),
        ),
        const SizedBox(height: AuraSpace.md),
        AuraPrimaryButton(
          label: 'Start verification',
          onPressed: widget.busy || _selected == null
              ? null
              : () => widget.onStart(_selected!),
        ),
      ],
    );
  }
}

class _EvidenceList extends StatefulWidget {
  const _EvidenceList({
    required this.staged,
    required this.onAddDocument,
    required this.onAddReference,
    required this.onRemove,
    required this.onRetry,
  });

  final List<_Staged> staged;
  final Future<void> Function() onAddDocument;
  final void Function(String) onAddReference;
  final void Function(_Staged) onRemove;
  final Future<void> Function(_Staged) onRetry;

  @override
  State<_EvidenceList> createState() => _EvidenceListState();
}

class _EvidenceListState extends State<_EvidenceList> {
  final _reference = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in widget.staged)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: item.uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    item.failure != null
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                  ),
            title: Text(item.label, style: AuraText.body),
            subtitle:
                item.failure == null ? null : Text(item.failure!, style: AuraText.small),
            trailing: item.failure != null
                ? TextButton(
                    onPressed: () => widget.onRetry(item),
                    child: const Text('Retry'),
                  )
                : IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => widget.onRemove(item),
                  ),
          ),
        const SizedBox(height: AuraSpace.sm),
        AuraSecondaryButton(
          label: 'Add a document',
          onPressed: () => widget.onAddDocument(),
        ),
        const SizedBox(height: AuraSpace.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Or a registry number, listing or domain',
                ),
                onSubmitted: (v) {
                  widget.onAddReference(v);
                  _reference.clear();
                },
              ),
            ),
            const SizedBox(width: AuraSpace.sm),
            TextButton(
              onPressed: () {
                widget.onAddReference(_reference.text);
                _reference.clear();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }
}

/// THE 120-DAY DEADLINE, SHOWN ONLY WHEN ONE IS ACTUALLY RUNNING.
///
/// Rendered from `running`, which is false until a notice has been DELIVERED.
/// A card that appeared as soon as a migration record existed would show a
/// countdown to somebody who was never told anything — the exact thing §6's
/// delivery anchor exists to prevent, reintroduced at the last layer.
///
/// The DATE is shown, never "in 43 days". §6: "the specific deadline date is
/// always shown, computed from each population's own anchor — never relative
/// phrasing." Relative phrasing also drifts: a screen left open overnight
/// starts lying.
class _MigrationCard extends StatelessWidget {
  const _MigrationCard({required this.posture});

  final MigrationPosture posture;

  @override
  Widget build(BuildContext context) {
    final elapsed = posture.reason == 'WINDOW_ELAPSED';
    final date = posture.deadlineAt;
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Completing your verification', style: AuraText.title),
            const SizedBox(height: AuraSpace.xs),
            if (date != null)
              Text(
                elapsed
                    ? 'The date for this was ${AuraTemporal.absolute(ProductTime(date, TimeEvent.scheduled))}.'
                    : 'Please complete this by ${AuraTemporal.absolute(ProductTime(date, TimeEvent.scheduled))}.',
                style: AuraText.body,
              ),
            const SizedBox(height: AuraSpace.sm),
            // PLAIN AND SPECIFIC about the actual consequence, and non-punitive
            // throughout: §6 forbids both vagueness and any language implying
            // wrongdoing. Nothing here says the person did something wrong,
            // because they did not -- the standard changed.
            Text(
              elapsed
                  ? 'Until this is complete you cannot post as this institution, '
                      'and you cannot transfer ownership or change who represents '
                      'it. The institution, its content, its members and its '
                      'history are unaffected.'
                  : 'Until this is complete you cannot transfer ownership or '
                      'change who represents this institution. Posting as the '
                      'institution and everyday work carry on as normal.',
              style: AuraText.body,
            ),
            const SizedBox(height: AuraSpace.sm),
            const Text(
              'Nothing is deleted and no past post stops being yours.',
              style: AuraText.small,
            ),
          ],
        ),
      ),
    );
  }

}
