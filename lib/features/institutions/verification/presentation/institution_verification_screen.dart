import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/attachments/aura_media_upload.dart';
import '../../../../core/media/media_acquisition.dart';
import '../../../../core/net/dio_provider.dart';
import '../../../../core/navigation/navigation_authority.dart';
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
///
///   IT DOES NOT ASK A VERIFIED PERSON TO VERIFY AGAIN (founder, 2026-09-19).
///   Who the person is and whether they may represent this institution are
///   separate facts. A verified owner is told their identity is verified and
///   is asked only for evidence of their relationship or authority — a
///   registration, formation or governing document naming them, as a PDF or
///   an image. One document may be enough.
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
  final TextEditingController _claimedRole = TextEditingController();

  AuthorityEvidenceKind? _chosenKind;

  /// Whether the authority document also shows the institution exists. Null
  /// until the person touches it, so the default can follow the standing.
  bool? _alsoEstablishes;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _claimedRole.dispose();
    super.dispose();
  }

  /// WHO MAY ACT HERE, SPLIT BY WHAT IS MISSING. A person with no current
  /// identity verification is sent to verify it first; a verified person is
  /// never sent back there, whatever else the standing says.
  bool _needsIdentityFirst(InstitutionVerificationStanding s) =>
      !s.mayAct && !s.identityVerified;

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
              // RECOGNISED FIRST. The person's own identity is stated before
              // anything is asked of them, so nobody reads the steps below as
              // Aura failing to know who they are.
              if (s.identityVerified) ...[
                _IdentityRecognisedNote(expiresAt: s.identityExpiresAt),
                const SizedBox(height: AuraSpace.lg),
              ],
              if (!s.started && !_needsIdentityFirst(s)) ...[
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Start here', style: AuraText.title),
                        const SizedBox(height: AuraSpace.sm),
                        const Text(
                          'Tell us what kind of organisation this is. The '
                          'evidence asked for below follows from it.',
                          style: AuraText.body,
                        ),
                        const SizedBox(height: AuraSpace.md),
                        _StartRow(
                          busy: _busy,
                          onStart: (category) => _guard(() async {
                            await ref
                                .read(institutionVerificationRepositoryProvider)
                                .start(widget.institutionId, category);
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AuraSpace.lg),
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
      // SUSPENDED is a pause, not a severance, and LEGACY_UNVERIFIED is a
      // role carried over that simply has not been evidenced yet. Colouring
      // either as a problem would tell somebody they had lost something
      // they have not — their role and history are untouched.
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
    if (s.existence.state == ExistenceState.notStarted && !s.started) {
      return 'Tell us what kind of organisation this is, and what you can show '
          'us about it.';
    }
    if (s.existence.state == ExistenceState.notStarted && s.existence.acceptsEvidence) {
      // The one-document path is said here too, so nobody hunts for a second
      // document to prove the same institution twice.
      return 'A registration or formation document usually shows this. If the '
          'document you give below for your authority also shows the '
          'institution is registered, that is enough for both.';
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
    // BEFORE THE TRANSITION TABLE: may this person act at all?
    //
    // Reading this standing needs institution ADMIN; submitting a proof needs
    // a current verified identity. Only somebody WITHOUT one is sent to verify
    // it — a verified person is never sent back to identity for this.
    if (_needsIdentityFirst(s)) return const _IdentityFirstNote();

    // Nothing to attach until the organisation's kind is recorded; the start
    // card above asks for it.
    if (!s.started) return const SizedBox.shrink();

    // RENDERED FROM THE SERVER'S PROJECTION, never from the state. A button
    // exists here only where the transition table has an edge.
    final canSubmit = s.existence.canSubmit('SUBMITTED');
    if (!canSubmit && !s.existence.acceptsEvidence) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        // No grace period any more (founder, 2026-09-19): a carried-over role
        // does not speak for the institution until its authority is evidenced.
        return 'Your role here came across from the old system and has not been '
            'evidenced yet. Your role and history are unchanged; to speak for '
            'this institution, provide evidence of your relationship or '
            'authority below.';
      case AuthorityState.suspended:
        return 'This is a pause, not a removal. Your role and your history are '
            'untouched.';
      case AuthorityState.confirmed:
        return 'This is about your authority only. Whether the institution '
            'itself is confirmed is the separate question above.';
      default:
        if (s.authority.acceptsEvidence) {
          return 'To speak for this institution, provide evidence of your '
              'relationship or authority. One document can be enough when it '
              'names you in your role and identifies the institution — the '
              'reviewer may ask for more.';
        }
        return '';
    }
  }

  Widget _authorityActions(InstitutionVerificationStanding s) {
    // Same gate as the existence proof above, and stated once per card rather
    // than once per screen: these are two separate questions and a person
    // reading only one of them still needs the answer.
    if (_needsIdentityFirst(s)) return const _IdentityFirstNote();
    if (!s.started) {
      return const Text(
        'Start above by saying what kind of organisation this is.',
        style: AuraText.small,
      );
    }

    final canSubmit = s.authority.canSubmit('SUBMITTED');
    if (!canSubmit && !s.authority.acceptsEvidence) {
      return const SizedBox.shrink();
    }

    // One document may prove both questions. Offered only where the
    // institution's own proof can still take evidence, and ticked by default
    // there, because for an ordinary owner the registration that names them
    // is also the registration that shows the institution exists.
    final canAlsoEstablish = s.existence.acceptsEvidence &&
        s.existence.state != ExistenceState.confirmed;
    final alsoEstablishes = canAlsoEstablish && (_alsoEstablishes ?? true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.authority.acceptsEvidence && s.menu.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.sm),
          TextField(
            controller: _claimedRole,
            enabled: !_busy,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Your role at this institution',
              hintText: 'For example: Founder and managing member',
              helperText: s.claimedRole == null
                  ? 'The reviewer checks your evidence against this.'
                  : 'On record: ${s.claimedRole}',
            ),
          ),
          const SizedBox(height: AuraSpace.sm),
          const Text('What does your evidence show?', style: AuraText.body),
          // THE WHOLE MENU, always. §2.7 says any one item suffices; a
          // dropdown showing only a suggested item would turn an advisory
          // mapping into a requirement -- a policy change made by a form.
          RadioGroup<AuthorityEvidenceKind>(
            groupValue: _chosenKind,
            onChanged: (v) {
              if (!_busy) setState(() => _chosenKind = v);
            },
            child: Column(
              children: [
                for (final kind in s.menu)
                  RadioListTile<AuthorityEvidenceKind>(
                    value: kind,
                    enabled: !_busy,
                    title: Text(kind.label, style: AuraText.body),
                    subtitle: kind.help == null
                        ? null
                        : Text(kind.help!, style: AuraText.small),
                    dense: true,
                  ),
              ],
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
          if (canAlsoEstablish)
            CheckboxListTile(
              value: alsoEstablishes,
              onChanged:
                  _busy ? null : (v) => setState(() => _alsoEstablishes = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'This document also shows the institution is registered',
                style: AuraText.body,
              ),
              subtitle: const Text(
                'It is then used for both questions, so you do not need a '
                'second document. The reviewer decides each one.',
                style: AuraText.small,
              ),
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
                      final repo =
                          ref.read(institutionVerificationRepositoryProvider);
                      // The authority claim is created by `start`, which is
                      // idempotent. A person whose institution was started
                      // by somebody else has no claim of their own yet, so it
                      // is opened here rather than refused as "not started".
                      await repo.start(widget.institutionId, s.category!);
                      await repo.submitAuthority(
                        widget.institutionId,
                        evidenceKind: _chosenKind!,
                        claimedRole: _claimedRole.text,
                        alsoEstablishesInstitution: alsoEstablishes,
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
                      _alsoEstablishes = null;
                      _claimedRole.clear();
                    }),
          ),
        ],
      ],
    );
  }

  // ── evidence acquisition ──────────────────────────────────────────────────

  bool _anyReady(List<_Staged> items) => items.any((e) => e.ready);

  Future<void> _addDocument(List<_Staged> into) async {
    // A PDF OR AN IMAGE (founder, 2026-09-19). A certificate of formation or a
    // registry extract usually arrives as a PDF, which the image pickers could
    // not offer. No re-encoding either way: a downscaled document can lose
    // exactly the small print a reviewer needs.
    final acquisition = await acquireSingleDocument();
    if (!mounted) return;

    // `null` means CANCELLED and nothing else. Every failure path returns a
    // rejection carrying a reason, so silence here can only be a person
    // changing their mind -- and changing your mind is not an error.
    if (acquisition == null) return;

    final document = acquisition.document;
    if (document == null) {
      setState(() => _error = acquisition.rejectionMessage ??
          'That file could not be added. Try another.');
      return;
    }

    final staged = _Staged(label: document.fileName);
    setState(() {
      into.add(staged);
      _error = null;
      staged.uploading = true;
    });

    await _upload(staged, document);
  }

  Future<void> _upload(_Staged staged, AcquiredDocument document) async {
    try {
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: document.bytes,
        fileName: staged.label,
        mimeType: document.mimeType,
        // The media door types a PDF as a DOCUMENT; the server admits either
        // as institutional evidence and nothing else.
        kind: document.isPdf ? 'DOCUMENT' : 'IMAGE',
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
    final acquisition = await acquireSingleDocument();
    if (!mounted) return;
    final document = acquisition?.document;
    if (document == null) {
      setState(() {
        staged.uploading = false;
        staged.failure = acquisition?.rejectionMessage ??
            'That did not upload. Tap to try again.';
      });
      return;
    }
    await _upload(staged, document);
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
    final colour = switch (tone) {
      _Tone.problem => scheme.error,
      _Tone.good => scheme.primary,
      _ => scheme.tertiary,
    };
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

/// WHAT IS ACTUALLY REQUIRED, AND THE WAY TO IT.
///
/// Shown in place of the proof actions ONLY when this person has no current
/// identity verification at all. It is never shown to a verified person: the
/// defect of 2026-09-19 was exactly that, a verified owner told their identity
/// "comes first" because a stronger tier was being asked for. Institution
/// authority is not a stronger identity; it is a separate question.
///
/// Non-punitive, matching the refusal copy the server sends for the same
/// situation: the person has done nothing wrong, and general Aura use is
/// unaffected.
class _IdentityFirstNote extends StatelessWidget {
  const _IdentityFirstNote();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AuraSpace.sm),
        const Text(
          'Verify your identity first. Once that is done, this step opens '
          'here — nothing is lost in the meantime, and the rest of Aura is '
          'unaffected.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.sm),
        AuraSecondaryButton(
          label: 'Verify my identity',
          icon: Icons.badge_outlined,
          onPressed: () =>
              context.push(NavigationAuthority.identityVerificationRoute),
        ),
      ],
    );
  }
}

/// "Your identity is verified." Said first, so nothing below reads as Aura
/// failing to recognise the person looking at it.
class _IdentityRecognisedNote extends StatelessWidget {
  const _IdentityRecognisedNote({required this.expiresAt});

  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final until = expiresAt == null
        ? ''
        : ' It is valid until '
            '${AuraTemporal.calendar(ProductTime(expiresAt!, TimeEvent.scheduled))}.';
    return _Banner(
      message: 'Your identity is verified.$until To speak for this institution, '
          'provide evidence of your relationship or authority below — your '
          'identity is not checked again.',
      tone: _Tone.good,
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
          label: 'Add a document (PDF or image)',
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
