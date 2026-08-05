import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/session_providers.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/institutions/institution_access_provider.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../data/continuity_providers.dart';
import '../../domain/communication_continuity.dart';

/// Communication Governance v1.0, Roadmap Milestone 8.
///
/// Renders the frozen doctrine's Communication Continuity concept exactly
/// as the backend computed it — one independent row per
/// AccountabilityLifecycle for Raise Issue (never blended, per the
/// Communication Lifecycle vs. Accountability Lifecycle distinction), a
/// single Pending/Answered/Stale value for Ask, and nothing at all for
/// Share Update. This widget makes no governance decisions of its own —
/// Acknowledge/Resolve/Reopen are offered as affordances only; the backend
/// is the sole authority on whether an action actually succeeds.
class CommunicationContinuityView extends ConsumerWidget {
  const CommunicationContinuityView({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.postIntent,
  });

  final String postId;
  final String postAuthorId;

  /// Wire-cased Communication Intent (`ASK` / `ISSUE` / `UPDATE`) from
  /// `Post.intent`. Passed in so the view can skip the network call
  /// entirely for Share Update, which never has continuity.
  final String? postIntent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = (postIntent ?? '').toUpperCase().trim();
    if (intent != 'ASK' && intent != 'ISSUE') {
      return const SizedBox.shrink();
    }

    final continuityAsync = ref.watch(continuityProvider(postId));

    return continuityAsync.when(
      loading: () => const _ContinuitySkeleton(),
      error: (e, _) => const SizedBox.shrink(),
      data: (result) {
        if (result == null || result is ContinuityNone) {
          return const SizedBox.shrink();
        }
        if (result is AskContinuity) {
          return _AskContinuityCard(status: result.status, postId: postId);
        }
        if (result is RaiseIssueContinuity) {
          return _RaiseIssueContinuityCard(
            postId: postId,
            postAuthorId: postAuthorId,
            continuity: result,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _ContinuitySkeleton extends StatelessWidget {
  const _ContinuitySkeleton();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s14),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AuraSpace.s10),
            Text(
              'Loading communication status…',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionFrame({required Widget child}) {
  return AuraCard(
    child: Padding(
      padding: const EdgeInsets.all(AuraSpace.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Communication status',
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w800,
              color: AuraSurface.muted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          child,
        ],
      ),
    ),
  );
}

class _AskContinuityCard extends StatelessWidget {
  const _AskContinuityCard({required this.status, required this.postId});

  final AskContinuityStatus status;
  final String postId;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case AskContinuityStatus.answered:
        return _sectionFrame(
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 16, color: AuraSurface.coVerdant),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text('Answered.', style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      case AskContinuityStatus.stale:
        return _sectionFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No replies yet.',
                style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AuraSpace.s4),
              Text(
                "Questions like this don't always find an answer — that's alright.",
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
        );
      case AskContinuityStatus.pending:
      case AskContinuityStatus.unknown:
        return const SizedBox.shrink();
    }
  }
}

class _RaiseIssueContinuityCard extends ConsumerWidget {
  const _RaiseIssueContinuityCard({
    required this.postId,
    required this.postAuthorId,
    required this.continuity,
  });

  final String postId;
  final String postAuthorId;
  final RaiseIssueContinuity continuity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (continuity.unrouted) {
      return _sectionFrame(
        child: Text(
          'No accountable institution currently matches this topic. '
          'This has not yet been routed to anyone responsible.',
          style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4),
        ),
      );
    }

    final lifecycles = continuity.accountabilityLifecycles;
    if (lifecycles.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentUserId = ref.watch(authMeDataProvider).valueOrNull?['id']?.toString();
    final affiliations = ref.watch(myAffiliationsProvider);

    return _sectionFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lifecycles.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: AuraSpace.s12),
              const Divider(color: AuraSurface.divider, height: 1),
              const SizedBox(height: AuraSpace.s12),
            ],
            _AccountabilityLifecycleRow(
              postId: postId,
              postAuthorId: postAuthorId,
              lifecycle: lifecycles[i],
              currentUserId: currentUserId,
              affiliations: affiliations,
              multiInstitution: lifecycles.length > 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountabilityLifecycleRow extends ConsumerStatefulWidget {
  const _AccountabilityLifecycleRow({
    required this.postId,
    required this.postAuthorId,
    required this.lifecycle,
    required this.currentUserId,
    required this.affiliations,
    required this.multiInstitution,
  });

  final String postId;
  final String postAuthorId;
  final AccountabilityLifecycle lifecycle;
  final String? currentUserId;
  final List<MemberAffiliation> affiliations;
  final bool multiInstitution;

  @override
  ConsumerState<_AccountabilityLifecycleRow> createState() => _AccountabilityLifecycleRowState();
}

class _AccountabilityLifecycleRowState extends ConsumerState<_AccountabilityLifecycleRow> {
  bool _busy = false;

  MemberAffiliation? get _affiliation {
    for (final a in widget.affiliations) {
      if (a.id == widget.lifecycle.institutionId) return a;
    }
    return null;
  }

  bool get _isAuthor =>
      (widget.currentUserId ?? '').trim().isNotEmpty &&
      widget.currentUserId == widget.postAuthorId;

  /// Best-effort UI affordance only — the backend (OFFICIAL_REPRESENTATION)
  /// is the real gate. A member who lacks the capability simply sees the
  /// action fail with the server's own message.
  bool get _canActForInstitution => _affiliation != null;

  bool get _canResolve {
    final role = _affiliation?.role ?? '';
    return role == 'OWNER' || role == 'ADMIN';
  }

  String _institutionLabel() {
    final name = _affiliation?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    final id = widget.lifecycle.institutionId;
    return 'Institution ${id.length > 8 ? id.substring(0, 8) : id}';
  }

  String _statusLabel(AccountabilityLifecycle l) {
    switch (l.status) {
      case AccountabilityStatus.pending:
        return l.overdue ? 'Pending · Overdue' : 'Pending';
      case AccountabilityStatus.responded:
        return 'Responded';
      case AccountabilityStatus.committed:
        return l.overdue ? 'Committed · Overdue' : 'Committed';
      case AccountabilityStatus.resolved:
        return 'Resolved';
      case AccountabilityStatus.reopened:
        return 'Reopened';
      case AccountabilityStatus.stale:
        return 'Stale';
      case AccountabilityStatus.dormant:
        return 'Dormant';
      case AccountabilityStatus.institutionNoLongerActive:
        return 'No longer active';
      case AccountabilityStatus.unknown:
        return '—';
    }
  }

  IconData _statusIcon(AccountabilityLifecycle l) {
    switch (l.status) {
      case AccountabilityStatus.resolved:
        return Icons.check_circle_outline;
      case AccountabilityStatus.reopened:
        return Icons.replay_rounded;
      case AccountabilityStatus.stale:
      case AccountabilityStatus.dormant:
        return Icons.warning_amber_rounded;
      case AccountabilityStatus.institutionNoLongerActive:
        return Icons.block_outlined;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  Color _statusColor(AccountabilityLifecycle l) {
    switch (l.status) {
      case AccountabilityStatus.resolved:
        return AuraSurface.coVerdant;
      case AccountabilityStatus.stale:
      case AccountabilityStatus.dormant:
      case AccountabilityStatus.institutionNoLongerActive:
        return AuraSurface.coSun;
      default:
        return AuraSurface.muted;
    }
  }

  Future<void> _runAction(Future<void> Function() action, {required String failureFeature}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      // ignore: unused_result
      ref.invalidate(continuityProvider(widget.postId));
    } catch (e) {
      if (!mounted) return;
      final message = AppErrorMapper.from(e, feature: failureFeature).message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acknowledge() => _runAction(
        () => ref.read(continuityRepositoryProvider).acknowledge(
              postId: widget.postId,
              institutionId: widget.lifecycle.institutionId,
            ),
        failureFeature: 'acknowledge this',
      );

  Future<void> _reopen() => _runAction(
        () => ref.read(continuityRepositoryProvider).reopen(
              postId: widget.postId,
              institutionId: widget.lifecycle.institutionId,
            ),
        failureFeature: 'reopen this',
      );

  Future<void> _promptResolve() async {
    final controller = TextEditingController();
    final statement = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Resolved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Describe what was done, or why no action was warranted. '
              'This is recorded permanently as part of the record.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: controller,
              maxLines: 4,
              minLines: 2,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'What was done…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (statement == null || statement.trim().isEmpty) return;
    if (!mounted) return;
    await _runAction(
      () => ref.read(continuityRepositoryProvider).resolve(
            postId: widget.postId,
            institutionId: widget.lifecycle.institutionId,
            resolutionStatement: statement.trim(),
          ),
      failureFeature: 'resolve this',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lifecycle;
    final latest = l.resolutionHistory.isNotEmpty ? l.resolutionHistory.last : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.multiInstitution) ...[
          Text(
            _institutionLabel(),
            style: AuraText.small.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AuraSpace.s6),
        ],
        Row(
          children: [
            Icon(_statusIcon(l), size: 16, color: _statusColor(l)),
            const SizedBox(width: AuraSpace.s8),
            Text(
              _statusLabel(l),
              style: AuraText.small.copyWith(
                fontWeight: FontWeight.w700,
                color: _statusColor(l),
              ),
            ),
            if (l.isAcknowledged && l.status == AccountabilityStatus.pending) ...[
              const SizedBox(width: AuraSpace.s8),
              Text(
                '· Acknowledged',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ],
        ),
        if (latest != null) ...[
          const SizedBox(height: AuraSpace.s8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AuraSpace.s10),
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.md),
            ),
            child: Text(latest.statement, style: AuraText.small.copyWith(height: 1.4)),
          ),
          if (l.resolutionHistory.length > 1) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              'An earlier resolution is also on record, from before this was reopened.',
              style: AuraText.small.copyWith(color: AuraSurface.muted, fontStyle: FontStyle.italic),
            ),
          ],
        ],
        const SizedBox(height: AuraSpace.s10),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            if (l.status == AccountabilityStatus.pending &&
                !l.isAcknowledged &&
                _canActForInstitution)
              AuraSecondaryButton(
                label: 'Acknowledge',
                onPressed: _busy ? null : _acknowledge,
              ),
            if ((l.status == AccountabilityStatus.pending ||
                    l.status == AccountabilityStatus.responded ||
                    l.status == AccountabilityStatus.committed) &&
                _canResolve)
              AuraSecondaryButton(
                label: 'Resolve',
                onPressed: _busy ? null : _promptResolve,
              ),
            if (l.status == AccountabilityStatus.resolved &&
                !l.isReopened &&
                _isAuthor)
              AuraSecondaryButton(
                label: 'Reopen',
                onPressed: _busy ? null : _reopen,
              ),
          ],
        ),
      ],
    );
  }
}
