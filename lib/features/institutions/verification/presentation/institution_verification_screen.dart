import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/attachments/aura_media_upload.dart';
import '../../../../core/institutions/institution_access_provider.dart';
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

/// VERIFYING YOUR AUTHORITY FOR AN INSTITUTION — one flow, not two journeys.
///
/// THE MODEL IS STILL TWO FACTS. The institution existing and this person
/// being allowed to speak for it are separate determinations with separate
/// lifecycles, decided separately by a reviewer, and the policy says so in as
/// many words. What changed on 2026-09-19 is that the PERSON stopped being
/// walked through both: the backend records two answers; the owner supplies
/// one set of evidence.
///
/// WHAT THIS SCREEN REFUSES TO DO, each of which would be easier:
///
///   IT DOES NOT ASK A VERIFIED PERSON TO VERIFY AGAIN. Who somebody is and
///   whether they may represent this institution are different questions. A
///   verified owner is told their identity is verified and is asked only for
///   institutional evidence.
///
///   IT DOES NOT ASK FOR A SECOND DOCUMENT BEFORE A REVIEWER DOES. A
///   registration that names you is usually also the registration that shows
///   the institution exists, so it answers both by default. The institution's
///   own upload appears ONLY where a reviewer has actually asked for it.
///
///   IT DOES NOT ASK FOR WHAT AURA ALREADY HOLDS. The role on record is
///   proposed and confirmed, not retyped into an empty box beneath a line
///   that already states it.
///
///   IT DOES NOT SHOW A FORM AFTER THE ANSWER IS SENT. Once the claim is with
///   a reviewer the screen says so, with what was sent and who decides it.
///
///   IT DOES NOT DECIDE WHAT YOU MAY DO, and it does not reword a refusal.
///   Affordances come from the server's own `available` projection, and a
///   refusal is shown in the words the server chose.
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
  final List<_Staged> _authorityEvidence = [];
  final List<_Staged> _institutionEvidence = [];
  final TextEditingController _claimedRole = TextEditingController();

  /// The evidence kind being relied on. Null means "the primary one", resolved
  /// against the server's menu at build time so this build never invents an
  /// item the policy does not offer.
  AuthorityEvidenceKind? _chosenKind;

  /// The five other legal pathways stay available and stay quiet. An ordinary
  /// founder should not have to read them to do the obvious thing.
  bool _showOtherKinds = false;

  /// Whether the person is claiming a role other than the one on record.
  bool _roleDiffers = false;

  /// The organisation's kind, asked INSIDE this form and only when Aura has
  /// none recorded. Never a gate in front of the evidence.
  String? _category;

  /// Opt-out from the one-document default.
  bool? _alsoEstablishes;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _claimedRole.dispose();
    super.dispose();
  }

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
        // retryable and says so.
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

  /// The institution's own name where the workspace knows it. Used for the
  /// pending state, which must name what is in review rather than say "this".
  String? get _institutionName {
    final identity = ref.read(institutionIdentityProvider);
    if (identity == null) return null;
    final asked = widget.institutionId.trim();
    if (asked.isEmpty) return identity.name;
    return (identity.id == asked || identity.slug == asked) ? identity.name : null;
  }

  Widget _body(InstitutionVerificationStanding s) {
    final children = <Widget>[];

    if (_error != null) {
      children
        ..add(_Banner(message: _error!, tone: _Tone.problem))
        ..add(const SizedBox(height: AuraSpace.md));
    }

    // NO CURRENT IDENTITY: the one thing that genuinely comes first, and the
    // only case where this screen mentions identity verification at all.
    if (!s.identityVerified && !s.mayAct) {
      children.add(const _IdentityFirstCard());
      return _page(children);
    }

    // RECOGNISED FIRST, so nothing below reads as Aura failing to know who is
    // looking at it.
    if (s.identityVerified) {
      children
        ..add(_IdentityRecognisedNote(expiresAt: s.identityExpiresAt))
        ..add(const SizedBox(height: AuraSpace.lg));
    }

    children
      ..add(_authorityCard(s))
      ..add(const SizedBox(height: AuraSpace.md))
      ..add(_InstitutionRecordLine(standing: s));

    // THE ONLY PLACE THE INSTITUTION'S OWN UPLOAD APPEARS: a reviewer has
    // asked for something about the institution specifically. Then the ask is
    // shown verbatim, with a way to answer it.
    if (s.existence.state == ExistenceState.needsInfo) {
      children
        ..add(const SizedBox(height: AuraSpace.lg))
        ..add(_institutionAskCard(s));
    }

    children
      ..add(const SizedBox(height: AuraSpace.lg))
      ..add(const _ReviewerNote());

    return _page(children);
  }

  Widget _page(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: Center(
          child: ConstrainedBox(
            // Narrow layouts get the same content, not a reduced one. A person
            // completing this on a phone is the common case.
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );

  // ── the one card ──────────────────────────────────────────────────────────

  Widget _authorityCard(InstitutionVerificationStanding s) {
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Verify your authority for this institution',
              style: AuraText.title,
            ),
            const SizedBox(height: AuraSpace.xs),
            _StandingChip(
              label: _authorityLabel(s.authority.state),
              tone: _authorityTone(s.authority.state),
            ),
            const SizedBox(height: AuraSpace.sm),
            ..._authorityContent(s),
          ],
        ),
      ),
    );
  }

  List<Widget> _authorityContent(InstitutionVerificationStanding s) {
    switch (s.authority.state) {
      case AuthorityState.confirmed:
        return [
          const Text(
            'Your authority is confirmed. You can speak for this institution.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.sm),
          const Text(
            'Whether the institution itself is confirmed is a separate '
            'question, answered separately.',
            style: AuraText.small,
          ),
        ];

      // WITH A REVIEWER. The form is NOT shown again: a person who has sent
      // their document and sees an empty form reads it as nothing having
      // happened, and sends it twice.
      case AuthorityState.submitted:
      case AuthorityState.underReview:
        return [_PendingPanel(standing: s, institutionName: _institutionName)];

      case AuthorityState.needsInfo:
        return [
          if ((s.authority.infoRequested ?? '').trim().isNotEmpty) ...[
            // VERBATIM. This is the field that stops NEEDS_INFO being a dead
            // end, and paraphrasing it would put the dead end back.
            _Banner(message: s.authority.infoRequested!, tone: _Tone.waiting),
            const SizedBox(height: AuraSpace.md),
          ],
          const Text(
            'Add what the reviewer asked for and send it back.',
            style: AuraText.body,
          ),
          ..._authorityForm(s),
        ];

      case AuthorityState.rejected:
        return [
          const Text(
            'The evidence supplied was not accepted. You can provide different '
            'evidence — your role and history are unchanged.',
            style: AuraText.body,
          ),
          ..._authorityForm(s),
        ];

      case AuthorityState.revoked:
        return const [
          Text(
            'Your authority to speak for this institution has been withdrawn. '
            'Your role and your history are unchanged.',
            style: AuraText.body,
          ),
        ];

      case AuthorityState.suspended:
        return const [
          Text(
            'This is a pause, not a removal. Your role and your history are '
            'untouched.',
            style: AuraText.body,
          ),
        ];

      case AuthorityState.legacyUnverified:
        return [
          const Text(
            'Your role here came across from the old system and has not been '
            'evidenced yet. Your role and history are unchanged; provide a '
            'document showing your relationship or authority to speak for it.',
            style: AuraText.body,
          ),
          ..._authorityForm(s),
        ];

      case AuthorityState.notStarted:
      case AuthorityState.unknown:
        return [
          const Text(
            'Provide a document showing your relationship or authority. If the '
            'same document also establishes the institution, you will not need '
            'another one.',
            style: AuraText.body,
          ),
          ..._authorityForm(s),
        ];
    }
  }

  /// THE ONE FORM: role, what the evidence is, the document, and send.
  List<Widget> _authorityForm(InstitutionVerificationStanding s) {
    if (!s.authority.acceptsEvidence && !s.authority.canSubmit('SUBMITTED')) {
      return const [];
    }

    final kind = _effectiveKind(s);
    final alsoEstablishes =
        s.oneDocumentCanAnswerBoth && (_alsoEstablishes ?? true);

    return [
      const SizedBox(height: AuraSpace.md),
      _RoleField(
        onRecord: s.roleOnRecord,
        claimedAlready: s.claimedRole,
        controller: _claimedRole,
        differs: _roleDiffers,
        busy: _busy,
        onUseDifferent: () => setState(() => _roleDiffers = true),
        onUseRecord: () => setState(() {
          _roleDiffers = false;
          _claimedRole.clear();
        }),
      ),
      const SizedBox(height: AuraSpace.md),
      _EvidenceKindField(
        menu: s.menu,
        chosen: kind,
        expanded: _showOtherKinds,
        busy: _busy,
        onChanged: (v) => setState(() => _chosenKind = v),
        onExpand: () => setState(() => _showOtherKinds = true),
      ),
      const SizedBox(height: AuraSpace.sm),
      _EvidenceList(
        staged: _authorityEvidence,
        onAddDocument: () => _addDocument(_authorityEvidence),
        onAddReference: (value) => _addReference(_authorityEvidence, value),
        onRemove: (item) => setState(() => _authorityEvidence.remove(item)),
        onRetry: (item) => _retry(item),
      ),
      // ONE DOCUMENT, STATED RATHER THAN ASKED. The default is that the
      // document answers both questions; the opt-out is there for the person
      // whose document genuinely does not.
      if (s.oneDocumentCanAnswerBoth) ...[
        const SizedBox(height: AuraSpace.sm),
        _OneDocumentNote(
          alsoEstablishes: alsoEstablishes,
          busy: _busy,
          onChanged: (v) => setState(() => _alsoEstablishes = v),
        ),
      ],
      // Asked HERE, inside the form, and only when Aura has no answer. It was
      // a separate card in front of everything, which made a two-step journey
      // out of a single question.
      if (!s.categoryRecorded) ...[
        const SizedBox(height: AuraSpace.md),
        _CategoryField(
          value: _category,
          busy: _busy,
          onChanged: (v) => setState(() => _category = v),
        ),
      ],
      const SizedBox(height: AuraSpace.md),
      AuraPrimaryButton(
        label: s.authority.state == AuthorityState.needsInfo
            ? 'Send this back for review'
            : 'Submit for review',
        onPressed: _busy ||
                kind == null ||
                !_anyReady(_authorityEvidence) ||
                (!s.categoryRecorded && _category == null)
            ? null
            : () => _submitAuthority(s, kind, alsoEstablishes),
      ),
      const SizedBox(height: AuraSpace.sm),
      const Text(
        'Another authorised reviewer confirms this. You cannot decide your own '
        'claim, and neither can anyone else at this institution.',
        style: AuraText.small,
      ),
    ];
  }

  /// The kind being relied on: what the person chose, or the primary path.
  AuthorityEvidenceKind? _effectiveKind(InstitutionVerificationStanding s) {
    if (_chosenKind != null && s.menu.contains(_chosenKind)) return _chosenKind;
    if (s.menu.contains(AuthorityEvidenceKind.institutionalRecordNamingPerson)) {
      return AuthorityEvidenceKind.institutionalRecordNamingPerson;
    }
    return s.menu.isEmpty ? null : s.menu.first;
  }

  Future<void> _submitAuthority(
    InstitutionVerificationStanding s,
    AuthorityEvidenceKind kind,
    bool alsoEstablishes,
  ) {
    return _guard(() async {
      await ref.read(institutionVerificationRepositoryProvider).submitAuthority(
            widget.institutionId,
            evidenceKind: kind,
            // The role on record is the claim unless the person said otherwise.
            claimedRole: _roleDiffers
                ? _claimedRole.text
                : (s.roleOnRecord?.label ?? _claimedRole.text),
            category: s.categoryRecorded ? null : _category,
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
      _showOtherKinds = false;
      _roleDiffers = false;
      _claimedRole.clear();
    });
  }

  // ── the institution, asked for only when a reviewer asked ─────────────────

  Widget _institutionAskCard(InstitutionVerificationStanding s) {
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('About the institution itself', style: AuraText.title),
            const SizedBox(height: AuraSpace.sm),
            const Text(
              'The reviewer asked for something more about the organisation, '
              'separately from your own authority.',
              style: AuraText.body,
            ),
            if ((s.existence.infoRequested ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.md),
              _Banner(message: s.existence.infoRequested!, tone: _Tone.waiting),
            ],
            if (s.accepted.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.sm),
              Text('Any of these will do: ${s.accepted.join(' · ')}',
                  style: AuraText.small),
            ],
            const SizedBox(height: AuraSpace.md),
            _EvidenceList(
              staged: _institutionEvidence,
              onAddDocument: () => _addDocument(_institutionEvidence),
              onAddReference: (v) => _addReference(_institutionEvidence, v),
              onRemove: (item) =>
                  setState(() => _institutionEvidence.remove(item)),
              onRetry: (item) => _retry(item),
            ),
            const SizedBox(height: AuraSpace.md),
            AuraPrimaryButton(
              label: 'Send this back for review',
              onPressed: _busy || !_anyReady(_institutionEvidence)
                  ? null
                  : () => _guard(() async {
                        await ref
                            .read(institutionVerificationRepositoryProvider)
                            .submitExistence(
                              widget.institutionId,
                              _institutionEvidence
                                  .where((e) => e.ready)
                                  .map((e) => SuppliedEvidence(
                                        mediaId: e.mediaId,
                                        reference: e.reference,
                                      ))
                                  .toList(),
                            );
                        _institutionEvidence.clear();
                      }),
            ),
          ],
        ),
      ),
    );
  }

  // ── wording ───────────────────────────────────────────────────────────────

  String _authorityLabel(AuthorityState state) {
    switch (state) {
      case AuthorityState.notStarted:
        return 'Not started';
      case AuthorityState.submitted:
        return 'With a reviewer';
      case AuthorityState.underReview:
        return 'Being reviewed by a person';
      case AuthorityState.needsInfo:
        return 'We need something more';
      case AuthorityState.confirmed:
        return 'Confirmed';
      case AuthorityState.rejected:
        return 'Not confirmed';
      case AuthorityState.legacyUnverified:
        // NEVER shown as verified. §5.19 — "a distinct, honestly-labeled
        // state, never folded into any newly-defined evidenced category."
        return 'Carried over, not yet evidenced';
      case AuthorityState.suspended:
        return 'On hold';
      case AuthorityState.revoked:
        return 'Withdrawn';
      case AuthorityState.unknown:
        return 'In review';
    }
  }

  /// TONE IS NOT A VERDICT. An unknown state reads as WAITING, never as good
  /// or bad: a build that coloured a string it had never seen would eventually
  /// tell somebody they were confirmed, or refused, on the strength of a guess.
  _Tone _authorityTone(AuthorityState state) {
    switch (state) {
      case AuthorityState.confirmed:
        return _Tone.good;
      case AuthorityState.rejected:
      case AuthorityState.revoked:
        return _Tone.problem;
      // SUSPENDED is a pause, not a severance; LEGACY_UNVERIFIED is a role
      // carried over that has not been evidenced. Neither is a loss.
      case AuthorityState.suspended:
      case AuthorityState.legacyUnverified:
      case AuthorityState.needsInfo:
      case AuthorityState.submitted:
      case AuthorityState.underReview:
      case AuthorityState.unknown:
        return _Tone.waiting;
      case AuthorityState.notStarted:
        return _Tone.neutral;
    }
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

/// WHAT WAS SENT, AND WHO DECIDES IT.
///
/// Shown in place of the form while the claim is with a reviewer. Everything
/// here is a fact about the submission — never the documents themselves.
class _PendingPanel extends StatelessWidget {
  const _PendingPanel({required this.standing, this.institutionName});

  final InstitutionVerificationStanding standing;
  final String? institutionName;

  @override
  Widget build(BuildContext context) {
    final s = standing;
    final kind = s.authorityEvidenceKind;
    final role = s.claimedRole ?? s.roleOnRecord?.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.authority.state == AuthorityState.underReview
              ? 'A reviewer is looking at this now. There is nothing for you to do.'
              : 'Your evidence is with a reviewer. There is nothing for you to do.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.md),
        if (institutionName != null) _Fact('Institution', institutionName!),
        if (role != null) _Fact('Role claimed', role),
        _Fact(
          'Evidence received',
          [
            s.authorityEvidenceCount == 1
                ? '1 item'
                : '${s.authorityEvidenceCount} items',
            if (kind != null) kind.label,
          ].join(' · '),
        ),
        if (s.oneDocumentCanAnswerBoth == false &&
            s.existence.state != ExistenceState.confirmed)
          const _Fact('The institution', 'Being decided from the same evidence'),
        const SizedBox(height: AuraSpace.sm),
        const Text(
          'Another authorised reviewer decides it — nobody can confirm their '
          'own claim. You will be told the outcome here.',
          style: AuraText.small,
        ),
      ],
    );
  }
}

/// The institution's own standing, as CONTEXT rather than as a step. It is a
/// separate determination and stays visible; it is not a second journey.
class _InstitutionRecordLine extends StatelessWidget {
  const _InstitutionRecordLine({required this.standing});

  final InstitutionVerificationStanding standing;

  @override
  Widget build(BuildContext context) {
    final s = standing;
    final String state;
    switch (s.existence.state) {
      case ExistenceState.confirmed:
        state = s.existenceConfidence?.label ?? 'Confirmed';
      case ExistenceState.needsInfo:
        state = 'A reviewer asked for more';
      case ExistenceState.rejected:
        state = 'Not confirmed';
      case ExistenceState.notStarted:
        state = s.authorityInReview
            ? 'Being decided from the same evidence'
            : 'Not decided yet';
      case ExistenceState.submitted:
      case ExistenceState.automatedCheck:
      case ExistenceState.manualReview:
      case ExistenceState.unknown:
        state = 'In review';
    }
    return Row(
      children: [
        const Icon(Icons.account_balance_outlined, size: 16),
        const SizedBox(width: AuraSpace.sm),
        Expanded(
          child: Text(
            'Institution record: $state',
            style: AuraText.small,
          ),
        ),
      ],
    );
  }
}

/// AURA ALREADY KNOWS THE ROLE. It proposes it; the person confirms it or
/// says otherwise. The empty box under a line stating the answer is gone.
class _RoleField extends StatelessWidget {
  const _RoleField({
    required this.onRecord,
    required this.claimedAlready,
    required this.controller,
    required this.differs,
    required this.busy,
    required this.onUseDifferent,
    required this.onUseRecord,
  });

  final RoleOnRecord? onRecord;
  final String? claimedAlready;
  final TextEditingController controller;
  final bool differs;
  final bool busy;
  final VoidCallback onUseDifferent;
  final VoidCallback onUseRecord;

  @override
  Widget build(BuildContext context) {
    final proposed = onRecord?.label ?? claimedAlready;

    // Nothing on record: ask once, plainly.
    if (proposed == null || differs) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            enabled: !busy,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Your role at this institution',
              hintText: 'For example: Founder and managing member',
              helperText: 'The reviewer checks your evidence against this.',
            ),
          ),
          if (proposed != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy ? null : onUseRecord,
                child: Text('Use my role on record: $proposed'),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Aura has you here as $proposed.', style: AuraText.body),
        const SizedBox(height: AuraSpace.xs),
        const Text(
          'This is the role your evidence will be checked against.',
          style: AuraText.small,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy ? null : onUseDifferent,
            child: const Text('Use a different role'),
          ),
        ),
      ],
    );
  }
}

/// THE PRIMARY PATH FIRST, THE MENU STILL WHOLE.
///
/// §2.7 says any one item suffices, so nothing is removed — but an ordinary
/// founder should not have to read five legal pathways to send the document
/// that obviously applies. The rest stay one tap away.
class _EvidenceKindField extends StatelessWidget {
  const _EvidenceKindField({
    required this.menu,
    required this.chosen,
    required this.expanded,
    required this.busy,
    required this.onChanged,
    required this.onExpand,
  });

  final List<AuthorityEvidenceKind> menu;
  final AuthorityEvidenceKind? chosen;
  final bool expanded;
  final bool busy;
  final ValueChanged<AuthorityEvidenceKind?> onChanged;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    if (menu.isEmpty) return const SizedBox.shrink();
    final primary =
        menu.contains(AuthorityEvidenceKind.institutionalRecordNamingPerson)
            ? AuthorityEvidenceKind.institutionalRecordNamingPerson
            : menu.first;
    final others = menu.where((k) => k != primary).toList(growable: false);
    final showAll = expanded || (chosen != null && chosen != primary);

    if (!showAll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What your evidence is', style: AuraText.body),
          const SizedBox(height: AuraSpace.xs),
          Text(primary.label, style: AuraText.body),
          if (primary.help != null)
            Text(primary.help!, style: AuraText.small),
          if (others.isNotEmpty)
            TextButton(
              onPressed: busy ? null : onExpand,
              child: const Text('My evidence is something else'),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What your evidence is', style: AuraText.body),
        RadioGroup<AuthorityEvidenceKind>(
          groupValue: chosen ?? primary,
          onChanged: (v) {
            if (!busy) onChanged(v);
          },
          child: Column(
            children: [
              for (final kind in menu)
                RadioListTile<AuthorityEvidenceKind>(
                  value: kind,
                  enabled: !busy,
                  title: Text(kind.label, style: AuraText.body),
                  subtitle:
                      kind.help == null ? null : Text(kind.help!, style: AuraText.small),
                  dense: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ONE DOCUMENT MAY BE ENOUGH — said as a fact, with an opt-out. It is not a
/// decision the person has to reason about before they can continue.
class _OneDocumentNote extends StatelessWidget {
  const _OneDocumentNote({
    required this.alsoEstablishes,
    required this.busy,
    required this.onChanged,
  });

  final bool alsoEstablishes;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          alsoEstablishes
              ? 'If this document also shows the institution is registered, it '
                  'answers both questions and you will not need another one. '
                  'The reviewer decides each one.'
              : 'This will be used for your authority only. The institution '
                  'will be decided separately.',
          style: AuraText.small,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy ? null : () => onChanged(!alsoEstablishes),
            child: Text(
              alsoEstablishes
                  ? 'My document does not show the institution'
                  : 'Use it for the institution as well',
            ),
          ),
        ),
      ],
    );
  }
}

/// The closed taxonomy, asked inline and only when Aura holds no answer.
/// §1.1 — "expandable later only by deliberate decision, never open/free-text".
class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  static const categories = <String, String>{
    'GOVERNMENT_CIVIC': 'Government or civic body',
    'EDUCATIONAL': 'School, college or university',
    'NONPROFIT_COMMUNITY': 'Nonprofit or community organisation',
    'RELIGIOUS': 'Religious organisation',
    'CORPORATE_BUSINESS': 'Company or business',
    'MEDIA': 'Media or journalism',
    'HEALTHCARE': 'Healthcare provider',
  };

  final String? value;
  final bool busy;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        // A label AND a hint would hide the hint on Material. Asked as a
        // question so the field explains itself without one.
        labelText: 'What kind of organisation is this?',
        helperText: 'Asked once, because it decides what a reviewer looks for.',
      ),
      items: categories.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: busy ? null : onChanged,
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

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.xs),
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

/// WHAT IS ACTUALLY REQUIRED, AND THE WAY TO IT.
///
/// Shown ONLY when this person has no current identity verification at all.
/// It is never shown to a verified person: the defect of 2026-09-19 was
/// exactly that, a verified owner told their identity "comes first" because a
/// stronger tier was being asked for. Institution authority is not a stronger
/// identity; it is a separate question.
class _IdentityFirstCard extends StatelessWidget {
  const _IdentityFirstCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Verify your identity first',
              style: AuraText.title,
            ),
            const SizedBox(height: AuraSpace.sm),
            const Text(
              'Once that is done, this step opens here and you will be asked '
              'only for evidence of your relationship or authority — nothing '
              'is lost in the meantime, and the rest of Aura is unaffected.',
              style: AuraText.body,
            ),
            const SizedBox(height: AuraSpace.md),
            AuraSecondaryButton(
              label: 'Verify my identity',
              icon: Icons.badge_outlined,
              onPressed: () =>
                  context.push(NavigationAuthority.identityVerificationRoute),
            ),
          ],
        ),
      ),
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

/// The separation, stated once at the foot rather than as two journeys.
class _ReviewerNote extends StatelessWidget {
  const _ReviewerNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Aura records two things about an institution — that it exists, and that '
      'a named person may speak for it. One document can answer both. An '
      'authorised reviewer who is not you decides each of them.',
      style: AuraText.small,
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
