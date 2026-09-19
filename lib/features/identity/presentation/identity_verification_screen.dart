import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/composition/content_intake.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/media/media_acquisition.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/identity_verification_repository.dart';

/// VERIFY YOUR IDENTITY — the person's side of the governed lifecycle.
///
/// Two pieces of evidence, one submission, and an honest account of what
/// happens to them afterwards. Everything on this screen is downstream of the
/// frozen policy:
///
///   * Two evidence roles, because Policy §1 names a government document and a
///     photograph of the submitter, and nothing else.
///   * The photo is called "photo of you", never "liveness" — a still image
///     compared by a reviewer is exactly that, and telling a person otherwise
///     would claim a check Aura does not perform.
///   * The 60-day destruction (Policy §6) is stated up front rather than
///     buried, because it is the single most reassuring thing about handing
///     over a passport and the person deciding whether to do so should have it
///     before they decide, not after.
///   * A rejection shows when they may try again (Policy §7's "never
///     permanent"), because a refusal with no horizon reads as a ban.
///   * The document is chosen first and its sides follow from it (founder,
///     2026-09-19): a licence or identity card needs its back, a passport
///     needs its photo page. The server states the rule; this renders it.
///   * A person who is already verified is RECOGNISED, not re-asked. They see
///     their verification and its dates, never the first-time form.
class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

/// One evidence slot: the photo of the person, or one side of the document.
typedef _Slot = ({IdentityEvidenceKind kind, IdentityEvidenceSide? side});

const _Slot _selfieSlot = (kind: IdentityEvidenceKind.selfieComparison, side: null);

class _PendingEvidence {
  _PendingEvidence({required this.slot, required this.bytes, required this.name});

  final _Slot slot;
  final Uint8List bytes;
  final String name;
  String? mediaId;
  bool uploading = false;
  String? error;
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  final Map<_Slot, _PendingEvidence> _staged = {};

  /// The document being presented. It decides which sides are asked for, so
  /// nothing about the document is offered until it is chosen.
  IdentityDocumentKind? _documentKind;
  bool _busy = false;
  String? _error;

  /// Every slot the chosen document can fill, required first, then the photo
  /// of the person.
  List<({_Slot slot, bool required})> _slotsFor(IdentityVerificationStatus status) {
    final kind = _documentKind;
    if (kind == null) return const [];
    final rule = status.sidesFor(kind);
    return [
      for (final side in rule.required)
        (slot: (kind: IdentityEvidenceKind.governmentId, side: side), required: true),
      for (final side in rule.optional)
        (slot: (kind: IdentityEvidenceKind.governmentId, side: side), required: false),
      (slot: _selfieSlot, required: true),
    ];
  }

  /// Ready when every REQUIRED slot has finished uploading and nothing is
  /// still in flight. An optional side may be left empty.
  bool _readyFor(IdentityVerificationStatus status) {
    final slots = _slotsFor(status);
    if (slots.isEmpty) return false;
    if (_staged.values.any((p) => p.uploading)) return false;
    return slots
        .where((s) => s.required)
        .every((s) => _staged[s.slot]?.mediaId != null);
  }

  /// A different document has different sides. Images staged for a side the
  /// new document does not have are dropped rather than sent as something
  /// they are not; the photo of the person is kept.
  void _chooseDocument(IdentityVerificationStatus status, IdentityDocumentKind kind) {
    setState(() {
      _documentKind = kind;
      final allowed = _slotsFor(status).map((s) => s.slot).toSet();
      _staged.removeWhere((slot, _) => !allowed.contains(slot));
      _error = null;
    });
  }

  // ── Acquisition ───────────────────────────────────────────────────────────

  /// Offer capture only where a camera actually exists.
  ///
  /// `supportsCameraCapture` is the platform authority for this, and it is
  /// Android/iOS only — the web has no in-process camera, and neither does
  /// Windows. On those, "choose a file" is the honest and only verb.
  Future<void> _pick(_Slot slot) async {
    if (_busy) return;

    if (!supportsCameraCapture) {
      await _acquireFromLibrary(slot);
      return;
    }

    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AuraSurface.card,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AuraRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AuraSpace.s12),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(
                slot.kind == IdentityEvidenceKind.selfieComparison
                    ? 'Take a photo of yourself'
                    : 'Photograph the document',
                style: AuraText.body,
              ),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose an existing photo', style: AuraText.body),
              onTap: () => Navigator.of(sheetContext).pop('library'),
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
        ),
      ),
    );

    if (source == 'camera') {
      await _acquireFromCamera(slot);
    } else if (source == 'library') {
      await _acquireFromLibrary(slot);
    }
  }

  Future<void> _acquireFromCamera(_Slot slot) async {
    final acquired = await capturePhoto(remainingSlots: 1);
    final resolution =
        acquired.resolutions.isEmpty ? null : acquired.resolutions.first;
    await _stage(slot, resolution);
  }

  Future<void> _acquireFromLibrary(_Slot slot) async {
    // No `imageQuality` downscale: a re-encoded document can lose exactly the
    // small print a reviewer needs, and an unreadable document costs the
    // person a whole NEEDS_MORE_INFO round trip.
    final resolution = await acquireSingleImage();
    await _stage(slot, resolution);
  }

  /// TYPED, not `dynamic`.
  ///
  /// This took `dynamic` and reached `resolution.rejectionMessage` through it,
  /// so the compiler could not check that a rejection carries a message at all
  /// — and a rename would have failed at runtime, in front of somebody, as a
  /// screen that does nothing. The web picker defect of 2026-09-10 was silence
  /// of exactly that shape, and untyped plumbing is how silence survives.
  Future<void> _stage(_Slot slot, IntakeResolution? resolution) async {
    // `null` means CANCELLED and nothing else. Every failure path now returns a
    // rejection carrying a reason, so silence here can only ever mean the
    // person changed their mind.
    if (resolution == null || !mounted) return;

    final attachment = resolution.attachment;
    if (attachment == null) {
      setState(
        () => _error = resolution.rejectionMessage ??
            'That file could not be added. Try another.',
      );
      return;
    }
    final bytes = attachment.bytes;
    if (bytes == null) {
      setState(() => _error = 'That file could not be read. Try another.');
      return;
    }

    // `attachment.fileName`, NOT `attachment.name`.
    //
    // `Attachment` has no `name`. This line read one through a `dynamic`
    // resolution, so it compiled, shipped, and threw NoSuchMethodError on EVERY
    // successful pick — unhandled, because `_pick` has no catch. The person
    // chose their document and the screen did nothing at all: no preview, no
    // error, no upload. That is the defect the founder reported on 2026-09-10,
    // and typing this method is what surfaced it.
    final pending = _PendingEvidence(
      slot: slot,
      bytes: bytes,
      name: attachment.fileName ?? 'evidence',
    );
    setState(() {
      _staged[slot] = pending;
      _error = null;
      pending.uploading = true;
    });

    // Uploaded immediately rather than at submit: a person on a phone should
    // find out a 12MB photo failed while they are still looking at the
    // picker, not after they have filled in everything else.
    try {
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: bytes,
        fileName: pending.name,
        mimeType: attachment.mimeType ?? 'image/jpeg',
        kind: 'IMAGE',
        source: 'UPLOAD',
      );
      if (!mounted) return;
      setState(() {
        pending.mediaId = result.mediaId;
        pending.uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pending.uploading = false;
        pending.error = AppErrorMapper.from(e, feature: 'upload this').message;
      });
    }
  }

  // ── Submission ────────────────────────────────────────────────────────────

  Future<void> _submit(IdentityVerificationStatus status) async {
    final kind = _documentKind;
    if (_busy || kind == null || !_readyFor(status)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final allowed = _slotsFor(status).map((s) => s.slot).toSet();
      await ref.read(identityVerificationRepositoryProvider).submit(
            documentKind: kind,
            evidence: [
              for (final entry in _staged.entries)
                if (allowed.contains(entry.key) && entry.value.mediaId != null)
                  (
                    mediaId: entry.value.mediaId!,
                    kind: entry.key.kind,
                    side: entry.key.side,
                  ),
            ],
          );
      if (!mounted) return;
      _staged.clear();
      _documentKind = null;
      ref.invalidate(identityVerificationStatusProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppErrorMapper.from(e, feature: 'submit this').message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(String submissionId) async {
    setState(() => _busy = true);
    try {
      await ref.read(identityVerificationRepositoryProvider).withdraw(submissionId);
      if (!mounted) return;
      ref.invalidate(identityVerificationStatusProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppErrorMapper.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Presentation ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(identityVerificationStatusProvider);

    return AuraScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kFormWidth),
              child: status.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AuraSpace.s24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => AuraCard(
                  child: Text(
                    AppErrorMapper.from(e).message,
                    style: AuraText.body,
                  ),
                ),
                data: _body,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(IdentityVerificationStatus status) {
    // RECOGNISE FIRST (founder, 2026-09-19). A person whose identity is
    // verified is told so, with its dates, and is NOT shown the first-time
    // form. Speaking for an institution is a separate authority question
    // answered on that institution's own Verification page — it never sends a
    // verified person back here.
    final verified = status.verified;
    if (verified != null) {
      final current = status.current;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your identity', style: AuraText.title),
          const SizedBox(height: AuraSpace.s20),
          _VerifiedCard(verified: verified),
          const SizedBox(height: AuraSpace.s20),
          const _VerifiedClassesCard(),
          // An open request alongside a verification in force is rare, but if
          // one exists the person must still be able to see and withdraw it.
          if (current != null && current.state.isOpen) ...[
            const SizedBox(height: AuraSpace.s20),
            _StatusCard(
              submission: current,
              retryAfter: status.retryAfter,
              onWithdraw: !_busy ? () => _withdraw(current.id) : null,
            ),
          ],
        ],
      );
    }

    final current = status.current;
    final showForm = current == null || !current.state.isOpen;
    final slots = _slotsFor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verify your identity', style: AuraText.title),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'A reviewer at Aura compares a government document with a photo of you. '
          'Nobody else sees either one, and both are destroyed 60 days after the review ends.',
          style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
        ),
        const SizedBox(height: AuraSpace.s20),

        // WHAT AURA HAS ALREADY VERIFIED, AND IT IS NOT ONE THING.
        //
        // Placed above the submission form on purpose: someone arriving here
        // wants to know where they stand before being asked to do anything,
        // and an expired class is exactly the thing they came to find out.
        const _VerifiedClassesCard(),
        const SizedBox(height: AuraSpace.s20),

        if (_error != null) ...[
          _Banner(message: _error!, tone: _BannerTone.bad),
          const SizedBox(height: AuraSpace.s14),
        ],

        if (current != null) ...[
          _StatusCard(
            submission: current,
            retryAfter: status.retryAfter,
            onWithdraw: current.state.isOpen && !_busy
                ? () => _withdraw(current.id)
                : null,
          ),
          const SizedBox(height: AuraSpace.s20),
        ],

        if (showForm && status.canSubmit) ...[
          _DocumentChoice(
            selected: _documentKind,
            onSelected: _busy ? null : (kind) => _chooseDocument(status, kind),
          ),
          const SizedBox(height: AuraSpace.s16),
          for (final s in slots) ...[
            _EvidenceTile(
              title: _slotTitle(s.slot, required: s.required),
              help: _slotHelp(s.slot),
              isPerson: s.slot.kind == IdentityEvidenceKind.selfieComparison,
              pending: _staged[s.slot],
              onPick: _busy ? null : () => _pick(s.slot),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          const SizedBox(height: AuraSpace.s8),
          // The confirmation of custody sits immediately above the button
          // that acts on it, not in a policy page nobody opens.
          const _Banner(
            message:
                'Your document and photo are stored privately, are never shown on your profile, '
                'and are deleted automatically 60 days after the review ends.',
            tone: _BannerTone.info,
          ),
          const SizedBox(height: AuraSpace.s16),
          SizedBox(
            width: double.infinity,
            child: AuraPrimaryButton(
              label: _busy ? 'Sending…' : 'Send for review',
              icon: _busy ? Icons.hourglass_top_rounded : Icons.shield_outlined,
              onPressed: (_busy || !_readyFor(status)) ? null : () => _submit(status),
            ),
          ),
        ] else if (showForm && !status.canSubmit) ...[
          _Banner(
            message: status.blockedReason ?? 'You cannot submit right now.',
            tone: _BannerTone.warn,
          ),
        ],
      ],
    );
  }

  String _slotTitle(_Slot slot, {required bool required}) {
    if (slot.kind == IdentityEvidenceKind.selfieComparison) {
      return IdentityEvidenceKind.selfieComparison.label;
    }
    final document = _documentKind?.label ?? 'Document';
    final side = slot.side?.label ?? 'Image';
    return required ? '$document — $side' : '$document — $side (optional)';
  }

  String _slotHelp(_Slot slot) {
    switch (slot.side) {
      case IdentityEvidenceSide.photoPage:
        return 'The page with your photo and details. All four corners visible, text readable.';
      case IdentityEvidenceSide.front:
        return 'The side with your photo. All four corners visible, text readable.';
      case IdentityEvidenceSide.back:
        return 'The reverse side. It often carries details the reviewer needs.';
      case null:
        return IdentityEvidenceKind.selfieComparison.help;
    }
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// The three governed classes, each with its own standing.
///
/// Never rendered as a single badge. The classes substantiate different
/// claims, and one tick covering all of them would assert something nobody
/// checked.
class _VerifiedClassesCard extends ConsumerWidget {
  const _VerifiedClassesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(personVerificationClassesProvider);

    return async.when(
      // Silent while unknown and silent on failure. This card reports what
      // Aura has verified; an error here means Aura does not currently know,
      // and guessing in either direction would be worse than saying nothing.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (classes) {
        if (classes.isEmpty) return const SizedBox.shrink();
        return AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What Aura has verified', style: AuraText.subtitle),
              const SizedBox(height: AuraSpace.s10),
              for (final c in classes) ...[
                _ClassRow(view: c),
                if (c != classes.last) const SizedBox(height: AuraSpace.s10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.view});

  final PersonVerificationClassView view;

  String get _label {
    switch (view.verificationClass) {
      case PersonVerificationClass.identity:
        return 'Who you are';
      case PersonVerificationClass.institutionAffiliation:
        return 'Your institution';
      case PersonVerificationClass.roleOrCredential:
        return view.classSubtype ?? 'A role or credential';
    }
  }

  /// Says WHY a class is not held, because absence and lapse are different
  /// facts and only one of them is worth acting on.
  String get _status {
    switch (view.state) {
      case PersonVerificationClassState.verified:
        final by = view.issuingAuthority;
        return by == null ? 'Verified' : 'Verified by $by';
      case PersonVerificationClassState.expired:
        return 'Expired';
      case PersonVerificationClassState.revoked:
        return 'No longer valid';
      case PersonVerificationClassState.notVerified:
        return 'Not verified';
    }
  }

  @override
  Widget build(BuildContext context) {
    final held = view.state == PersonVerificationClassState.verified;
    final lapsed = view.state == PersonVerificationClassState.expired ||
        view.state == PersonVerificationClassState.revoked;

    return Row(
      children: [
        Icon(
          held
              ? Icons.verified_rounded
              : lapsed
                  ? Icons.history_toggle_off_rounded
                  : Icons.radio_button_unchecked,
          size: 18,
          color: held
              ? AuraSurface.accentText
              : AuraSurface.muted,
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(child: Text(_label, style: AuraText.body)),
        Text(
          _status,
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
      ],
    );
  }
}

/// "Your identity is verified", with what Aura holds and until when.
///
/// Stated before anything else and in place of the form: the defect this
/// answers was a verified person being offered the first-time form again, and
/// reading that as Aura not recognising them.
class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({required this.verified});

  final VerifiedIdentity verified;

  @override
  Widget build(BuildContext context) {
    // Through the temporal authority, so these are the same dates every other
    // surface would show.
    String day(DateTime when) =>
        AuraTemporal.calendar(ProductTime(when, TimeEvent.occurred));

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, size: 20, color: AuraSurface.goodInk),
              SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text('Your identity is verified', style: AuraText.subtitle),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          if (verified.verifiedLegalName != null)
            _FactRow(label: 'Legal name', value: verified.verifiedLegalName!),
          if (verified.documentLabel != null)
            _FactRow(label: 'Document', value: verified.documentLabel!),
          if (verified.verifiedAt != null)
            _FactRow(label: 'Verified', value: day(verified.verifiedAt!)),
          _FactRow(
            label: 'Valid until',
            value: verified.expiresAt == null ? 'No expiry recorded' : day(verified.expiresAt!),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Nothing more is needed here. To speak for an institution, that '
            'institution asks for evidence of your role on its own Verification '
            'page — your identity is not checked again.',
            style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AuraText.small.copyWith(color: AuraSurface.muted)),
          ),
          Expanded(child: Text(value, style: AuraText.body)),
        ],
      ),
    );
  }
}

/// WHICH DOCUMENT. Asked first, because it decides which sides follow.
class _DocumentChoice extends StatelessWidget {
  const _DocumentChoice({required this.selected, required this.onSelected});

  final IdentityDocumentKind? selected;
  final ValueChanged<IdentityDocumentKind>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Which document are you using?', style: AuraText.body),
        const SizedBox(height: AuraSpace.s8),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            for (final kind in IdentityDocumentKind.values)
              ChoiceChip(
                label: Text(kind.label),
                selected: selected == kind,
                onSelected:
                    onSelected == null ? null : (_) => onSelected!(kind),
              ),
          ],
        ),
      ],
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.title,
    required this.help,
    required this.isPerson,
    this.pending,
    this.onPick,
  });

  final String title;
  final String help;
  final bool isPerson;
  final _PendingEvidence? pending;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final p = pending;
    final done = p?.mediaId != null;

    return AuraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done ? AuraSurface.goodBg : AuraSurface.accentSoft,
              borderRadius: BorderRadius.circular(AuraRadius.r12),
            ),
            child: Icon(
              done
                  ? Icons.check_rounded
                  : isPerson
                      ? Icons.person_outline
                      : Icons.badge_outlined,
              size: 20,
              color: done ? AuraSurface.goodInk : AuraSurface.accentText,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.body),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  p?.error ?? help,
                  style: AuraText.small.copyWith(
                    color: p?.error != null ? AuraSurface.dangerInk : AuraSurface.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AuraSpace.s10),
                if (p?.uploading == true)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  AuraSecondaryButton(
                    label: done
                        ? 'Replace'
                        : supportsCameraCapture
                            ? 'Add photo'
                            : 'Choose file',
                    onPressed: onPick,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.submission,
    required this.retryAfter,
    this.onWithdraw,
  });

  final IdentityVerificationSubmission submission;
  final DateTime? retryAfter;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final (headline, detail, tone) = _describe();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: AuraText.body),
          const SizedBox(height: AuraSpace.s6),
          Text(
            detail,
            style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4),
          ),
          if (submission.decisionReason != null) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              submission.decisionReason!,
              style: AuraText.small.copyWith(color: tone, height: 1.4),
            ),
          ],
          if (submission.evidence.any((e) => e.discarded)) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              'The document and photo you sent have been deleted.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          if (onWithdraw != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraSecondaryButton(label: 'Withdraw', onPressed: onWithdraw),
          ],
        ],
      ),
    );
  }

  (String, String, Color) _describe() {
    switch (submission.state) {
      case IdentityVerificationState.approved:
        return (
          'Your identity is verified',
          'A reviewer confirmed your document and photo.',
          AuraSurface.goodInk,
        );
      case IdentityVerificationState.needsMoreInfo:
        // NOT a failure, and worded so it cannot read as one. Policy §7 gives
        // this unlimited retries precisely because it is not a judgment.
        return (
          'We need something more',
          'Your verification is still open. Add what the reviewer asked for and it goes straight back to the queue.',
          AuraSurface.warnInk,
        );
      case IdentityVerificationState.rejected:
        final when = retryAfter;
        return (
          'We could not verify this',
          when == null
              ? 'You can try again with different evidence.'
              // Through the temporal authority, not a bare toLocal(): a
              // retry date a person plans around must be the same date every
              // other surface would show them.
              : 'You can try again after ${AuraTemporal.absolute(ProductTime(when, TimeEvent.occurred))}.',
          AuraSurface.dangerInk,
        );
      case IdentityVerificationState.withdrawn:
        return (
          'You withdrew this request',
          'Nothing was decided. You can start again whenever you like.',
          AuraSurface.muted,
        );
      case IdentityVerificationState.pendingReview:
      case IdentityVerificationState.unknown:
        return (
          'In review',
          'A reviewer will look at this. You do not need to do anything.',
          AuraSurface.muted,
        );
    }
  }
}

enum _BannerTone { info, warn, bad }

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.tone});

  final String message;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _BannerTone.info => AuraSurface.accentText,
      _BannerTone.warn => AuraSurface.warnInk,
      _BannerTone.bad => AuraSurface.dangerInk,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: AuraText.small.copyWith(color: color, height: 1.4),
      ),
    );
  }
}
