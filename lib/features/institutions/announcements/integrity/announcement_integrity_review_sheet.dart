import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../data/institutions_repository.dart';
import 'announcement_integrity.dart';

/// Communication Integrity Review — the publisher-facing surface for
/// Milestone 1 (institution announcements, Class D). Deliberately styled
/// unlike the app's writing-support panels: no pencil icon, no "suggestion"
/// language, a distinct visual register (a shield/ledger mark) so a
/// publisher can never mistake this for a grammar pass. It renders the
/// Communication Integrity Assessment and the governed next action — never
/// raw findings, confidence scores, or provider internals.
///
/// Returns `true` if the announcement was actually published from this
/// sheet, `false`/`null` otherwise (dismissed, or the user backed out).
Future<bool?> showAnnouncementIntegrityReviewSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String institutionId,
  required String announcementId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AnnouncementIntegrityReviewSheet(
      institutionId: institutionId,
      announcementId: announcementId,
      repo: ref.read(institutionsRepositoryProvider),
    ),
  );
}

class _AnnouncementIntegrityReviewSheet extends StatefulWidget {
  const _AnnouncementIntegrityReviewSheet({
    required this.institutionId,
    required this.announcementId,
    required this.repo,
  });

  final String institutionId;
  final String announcementId;
  final InstitutionsRepository repo;

  @override
  State<_AnnouncementIntegrityReviewSheet> createState() =>
      _AnnouncementIntegrityReviewSheetState();
}

class _AnnouncementIntegrityReviewSheetState
    extends State<_AnnouncementIntegrityReviewSheet> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  AnnouncementIntegrityAssessment? _assessment;
  AnnouncementIntegrityPendingAction? _pending;

  @override
  void initState() {
    super.initState();
    _runReview();
  }

  String _errorMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString().trim() ?? '';
        if (msg.isNotEmpty) return msg;
      }
    }
    return fallback;
  }

  Future<void> _runReview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.repo.requestAnnouncementIntegrityReview(
        widget.institutionId,
        widget.announcementId,
      );
      final result = AnnouncementIntegrityReviewResult.fromJson(raw);
      setState(() {
        _assessment = result.assessment;
        _pending = result.pendingAction;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _errorMessage(e, 'Could not complete the integrity review.');
        _loading = false;
      });
    }
  }

  Future<void> _satisfy(
    Future<Map<String, dynamic>> Function() call,
    String failureFallback,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = await call();
      final pending = AnnouncementIntegrityPendingAction.fromJson(
        Map<String, dynamic>.from(raw['pendingAction'] as Map),
      );
      setState(() {
        _pending = pending;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = _errorMessage(e, failureFallback);
        _busy = false;
      });
    }
  }

  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.publishInstitutionAnnouncement(
        widget.institutionId,
        widget.announcementId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = _errorMessage(e, 'Could not publish.');
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(AuraSpace.s12),
          padding: const EdgeInsets.all(AuraSpace.s20),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: AuraSurface.accentText,
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  Text(
                    'Communication Integrity Review',
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'Before this becomes institutional record.',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s16),
              if (_loading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AuraSpace.s20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (_assessment != null && _pending != null) ...[
                _buildAssessment(_assessment!),
                const SizedBox(height: AuraSpace.s16),
                _buildDecision(_pending!),
              ],
              if (_error != null) ...[
                const SizedBox(height: AuraSpace.s12),
                Text(
                  _error!,
                  style: AuraText.small.copyWith(color: AuraSurface.coRose),
                ),
              ],
              const SizedBox(height: AuraSpace.s16),
              Row(
                children: [
                  Expanded(
                    child: AuraSecondaryButton(
                      label: 'Close',
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: _buildPrimaryAction(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessment(AnnouncementIntegrityAssessment assessment) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assessment.statusLabel,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s4),
          Text(assessment.summaryExplanation, style: AuraText.small),
        ],
      ),
    );
  }

  Widget _buildDecision(AnnouncementIntegrityPendingAction pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pending.outcome.publisherLabel,
          style: AuraText.small.copyWith(
            fontWeight: FontWeight.w700,
            color: AuraSurface.accentText,
          ),
        ),
        const SizedBox(height: AuraSpace.s4),
        Text(pending.reason, style: AuraText.small.copyWith(color: AuraSurface.muted)),
        if (pending.outcome == AnnouncementIntegrityOutcome.requireAdditionalReviewer &&
            !pending.satisfied) ...[
          const SizedBox(height: AuraSpace.s12),
          AuraSecondaryButton(
            label: 'Review and approve as a second reviewer',
            onPressed: _busy
                ? null
                : () => _satisfy(
                    () => widget.repo.secondReviewAnnouncementIntegrity(
                      widget.institutionId,
                      widget.announcementId,
                      pending.decisionId,
                    ),
                    'Could not record the second review.',
                  ),
          ),
        ],
        if (pending.outcome ==
                AnnouncementIntegrityOutcome.requireInstitutionalApproval &&
            !pending.satisfied) ...[
          const SizedBox(height: AuraSpace.s12),
          AuraSecondaryButton(
            label: 'Approve as institution owner',
            onPressed: _busy
                ? null
                : () => _satisfy(
                    () => widget.repo.institutionalApprovalAnnouncementIntegrity(
                      widget.institutionId,
                      widget.announcementId,
                      pending.decisionId,
                    ),
                    'Could not record institutional approval.',
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrimaryAction() {
    if (_pending?.outcome == AnnouncementIntegrityOutcome.requireAcknowledgement &&
        !_pending!.satisfied) {
      return AuraPrimaryButton(
        label: 'I\'ve reviewed this — publish',
        onPressed: _busy
            ? null
            : () async {
                await _satisfy(
                  () => widget.repo.acknowledgeAnnouncementIntegrity(
                    widget.institutionId,
                    widget.announcementId,
                    _pending!.decisionId,
                  ),
                  'Could not record acknowledgement.',
                );
                if (_pending?.satisfied == true) await _publish();
              },
      );
    }

    final canPublish = _pending?.clearsPublish == true;
    return AuraPrimaryButton(
      label: _busy ? 'Publishing…' : 'Publish',
      onPressed: (_busy || !canPublish) ? null : _publish,
    );
  }
}
