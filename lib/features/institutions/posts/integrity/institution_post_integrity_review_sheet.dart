import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../announcements/integrity/announcement_integrity.dart';
import '../../data/institutions_repository.dart';
import '../../domain/institution_post.dart';

/// Publisher-facing Communication Integrity Review for institution posts.
///
/// The backend remains the publication authority. This sheet only exposes
/// the required action returned by the governance decision, records the
/// user's acknowledgement when required, and then retries the normal publish
/// endpoint so eligibility is re-evaluated server-side.
Future<bool?> showInstitutionPostIntegrityReviewSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String institutionId,
  required String postId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _InstitutionPostIntegrityReviewSheet(
      institutionId: institutionId,
      postId: postId,
      repo: ref.read(institutionsRepositoryProvider),
    ),
  );
}

class _InstitutionPostIntegrityReviewSheet extends StatefulWidget {
  const _InstitutionPostIntegrityReviewSheet({
    required this.institutionId,
    required this.postId,
    required this.repo,
  });

  final String institutionId;
  final String postId;
  final InstitutionsRepository repo;

  @override
  State<_InstitutionPostIntegrityReviewSheet> createState() =>
      _InstitutionPostIntegrityReviewSheetState();
}

class _InstitutionPostIntegrityReviewSheetState
    extends State<_InstitutionPostIntegrityReviewSheet> {
  bool _loading = true;
  bool _busy = false;
  bool _ackAccepted = false;
  String? _error;
  AnnouncementIntegrityAssessment? _assessment;
  AnnouncementIntegrityPendingAction? _pending;

  @override
  void initState() {
    super.initState();
    _runReview();
  }

  String _errorMessage(Object error, String fallback) {
    final appError = AppErrorMapper.from(error, feature: 'complete this review');
    if (appError.hasIssues) {
      return '${appError.message} (${appError.issues!.join('; ')})';
    }
    return appError.message.trim().isNotEmpty ? appError.message : fallback;
  }

  Future<void> _runReview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.repo.requestInstitutionPostIntegrityReview(
        widget.institutionId,
        widget.postId,
      );
      final result = AnnouncementIntegrityReviewResult.fromJson(raw);
      setState(() {
        _assessment = result.assessment;
        _pending = result.pendingAction;
        _ackAccepted = result.pendingAction.satisfied;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _errorMessage(e, 'Could not complete the integrity review.');
        _loading = false;
      });
    }
  }

  Future<bool> _satisfy(
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
        _ackAccepted = pending.satisfied;
        _busy = false;
      });
      return pending.satisfied;
    } catch (e) {
      setState(() {
        _error = _errorMessage(e, failureFallback);
        _busy = false;
      });
      return false;
    }
  }

  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final post = await widget.repo.publishInstitutionPost(
        widget.institutionId,
        widget.postId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(post.status == InstitutionPostStatus.published);
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
                  Expanded(child: _buildPrimaryAction()),
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
        const SizedBox(height: AuraSpace.s8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AuraSpace.s12),
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.md),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Text(
            pending.reason,
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ),
        if (pending.outcome ==
                AnnouncementIntegrityOutcome.requireAcknowledgement &&
            !pending.satisfied) ...[
          const SizedBox(height: AuraSpace.s12),
          CheckboxListTile(
            value: _ackAccepted,
            onChanged: _busy
                ? null
                : (value) => setState(() => _ackAccepted = value == true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AuraSurface.accent,
            title: Text(
              'I acknowledge this integrity requirement and accept responsibility for publishing under the institution voice.',
              style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        if (pending.outcome ==
                AnnouncementIntegrityOutcome.requireAdditionalReviewer &&
            !pending.satisfied) ...[
          const SizedBox(height: AuraSpace.s12),
          AuraSecondaryButton(
            label: 'Review and approve as a second reviewer',
            onPressed: _busy
                ? null
                : () => _satisfy(
                    () => widget.repo.secondReviewInstitutionPostIntegrity(
                      widget.institutionId,
                      widget.postId,
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
                    () => widget.repo
                        .institutionalApprovalInstitutionPostIntegrity(
                          widget.institutionId,
                          widget.postId,
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
    if (_pending?.outcome ==
            AnnouncementIntegrityOutcome.requireAcknowledgement &&
        !_pending!.satisfied) {
      return AuraPrimaryButton(
        label: _busy ? 'Recording...' : 'Acknowledge and publish',
        onPressed: (_busy || !_ackAccepted)
            ? null
            : () async {
                final satisfied = await _satisfy(
                  () => widget.repo.acknowledgeInstitutionPostIntegrity(
                    widget.institutionId,
                    widget.postId,
                    _pending!.decisionId,
                  ),
                  'Could not record acknowledgement.',
                );
                if (satisfied) await _publish();
              },
      );
    }

    final canPublish = _pending?.clearsPublish == true;
    return AuraPrimaryButton(
      label: _busy ? 'Publishing...' : 'Publish',
      onPressed: (_busy || !canPublish) ? null : _publish,
    );
  }
}
