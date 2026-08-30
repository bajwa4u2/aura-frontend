import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/attachments/aura_media_upload.dart';
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
class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _PendingEvidence {
  _PendingEvidence({required this.kind, required this.bytes, required this.name});

  final IdentityEvidenceKind kind;
  final Uint8List bytes;
  final String name;
  String? mediaId;
  bool uploading = false;
  String? error;
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  final Map<IdentityEvidenceKind, _PendingEvidence> _staged = {};
  final TextEditingController _documentType = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _documentType.dispose();
    super.dispose();
  }

  bool get _ready =>
      IdentityEvidenceKind.values.every((k) => _staged[k]?.mediaId != null);

  // ── Acquisition ───────────────────────────────────────────────────────────

  /// Offer capture only where a camera actually exists.
  ///
  /// `supportsCameraCapture` is the platform authority for this, and it is
  /// Android/iOS only — the web has no in-process camera, and neither does
  /// Windows. On those, "choose a file" is the honest and only verb.
  Future<void> _pick(IdentityEvidenceKind kind) async {
    if (_busy) return;

    if (!supportsCameraCapture) {
      await _acquireFromLibrary(kind);
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
                kind == IdentityEvidenceKind.selfieComparison
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
      await _acquireFromCamera(kind);
    } else if (source == 'library') {
      await _acquireFromLibrary(kind);
    }
  }

  Future<void> _acquireFromCamera(IdentityEvidenceKind kind) async {
    final acquired = await capturePhoto(remainingSlots: 1);
    final resolution =
        acquired.resolutions.isEmpty ? null : acquired.resolutions.first;
    await _stage(kind, resolution);
  }

  Future<void> _acquireFromLibrary(IdentityEvidenceKind kind) async {
    // No `imageQuality` downscale: a re-encoded document can lose exactly the
    // small print a reviewer needs, and an unreadable document costs the
    // person a whole NEEDS_MORE_INFO round trip.
    final resolution = await acquireSingleImage();
    await _stage(kind, resolution);
  }

  Future<void> _stage(IdentityEvidenceKind kind, dynamic resolution) async {
    if (resolution == null || !mounted) return;

    final attachment = resolution.attachment;
    if (attachment == null) {
      setState(() => _error = resolution.rejectionMessage as String?);
      return;
    }
    final bytes = attachment.bytes as Uint8List?;
    if (bytes == null) {
      setState(() => _error = 'That file could not be read. Try another.');
      return;
    }

    final pending = _PendingEvidence(
      kind: kind,
      bytes: bytes,
      name: (attachment.name as String?) ?? 'evidence',
    );
    setState(() {
      _staged[kind] = pending;
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
        mimeType: (attachment.mimeType as String?) ?? 'image/jpeg',
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

  Future<void> _submit() async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(identityVerificationRepositoryProvider).submit(
            evidence: IdentityEvidenceKind.values
                .map((k) => (mediaId: _staged[k]!.mediaId!, kind: k))
                .toList(),
            documentType: _documentType.text,
          );
      if (!mounted) return;
      _staged.clear();
      _documentType.clear();
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
    final current = status.current;
    final showForm = current == null || !current.state.isOpen;

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
          for (final kind in IdentityEvidenceKind.values) ...[
            _EvidenceTile(
              kind: kind,
              pending: _staged[kind],
              onPick: _busy ? null : () => _pick(kind),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          const SizedBox(height: AuraSpace.s4),
          TextField(
            controller: _documentType,
            decoration: const InputDecoration(
              labelText: 'What is the document? (optional)',
              hintText: 'Passport, national ID, driving licence…',
            ),
          ),
          const SizedBox(height: AuraSpace.s20),
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
              onPressed: (_busy || !_ready) ? null : _submit,
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
}

// ── Pieces ──────────────────────────────────────────────────────────────────

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.kind, this.pending, this.onPick});

  final IdentityEvidenceKind kind;
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
                  : kind == IdentityEvidenceKind.governmentId
                      ? Icons.badge_outlined
                      : Icons.person_outline,
              size: 20,
              color: done ? AuraSurface.goodInk : AuraSurface.accentText,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.label, style: AuraText.body),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  p?.error ?? kind.help,
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
