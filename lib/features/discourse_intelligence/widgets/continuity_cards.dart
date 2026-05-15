import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_item.dart' show FeedRouting;
import '../models.dart';

/// Civic-tone continuity cards. Used by `DiscourseContinuityPanel`
/// to render rows from the backend aggregation endpoints. Calm
/// infrastructural copy — no "trending", no rankings, no scores.

// ─────────────────────────────────────────────────────────────────────
//   ONGOING DISCUSSION
// ─────────────────────────────────────────────────────────────────────

/// One ongoing public discussion. Routes to the parent post; uses
/// `FeedRouting.adaptTargetRoute` so the user stays in the current
/// shell context.
class OngoingIssueCard extends StatelessWidget {
  const OngoingIssueCard({super.key, required this.issue});

  final DiscourseIssue issue;

  String _ageLabel() {
    if (issue.ageInDays <= 0) return 'today';
    if (issue.ageInDays == 1) return '1 day';
    return '${issue.ageInDays} days';
  }

  @override
  Widget build(BuildContext context) {
    final route = FeedRouting.adaptTargetRoute(
      issue.targetRoute,
      currentPath: GoRouterState.of(context).uri.path,
    );
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.r12),
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const _SignalEyebrow(
                    icon: Icons.forum_outlined,
                    label: 'ONGOING PUBLIC DISCUSSION',
                  ),
                  const Spacer(),
                  Text(
                    _ageLabel(),
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.faint,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                issue.preview.isEmpty ? 'Public discussion' : issue.preview,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              _ReplyFootline(
                replyCount: issue.replyCount,
                institutionReplyCount: issue.institutionReplyCount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyFootline extends StatelessWidget {
  const _ReplyFootline({
    required this.replyCount,
    required this.institutionReplyCount,
  });

  final int replyCount;
  final int institutionReplyCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
          style: AuraText.micro.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
        if (institutionReplyCount > 0) ...[
          const SizedBox(width: 6),
          Text(
            '· $institutionReplyCount institutional',
            style: AuraText.micro.copyWith(
              color: AuraSurface.accentText,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//   UNANSWERED PUBLIC QUESTION
// ─────────────────────────────────────────────────────────────────────

/// Public-space post that has drawn replies but no institution-voice
/// response. Surfaces `waitingHours` as observed time without an
/// institution reply — never a "score" or "rank".
class UnansweredQuestionCard extends StatelessWidget {
  const UnansweredQuestionCard({super.key, required this.question});

  final UnansweredQuestion question;

  String _waitingLabel() {
    if (question.waitingHours < 24) return '${question.waitingHours}h waiting';
    final days = question.waitingHours ~/ 24;
    if (days == 1) return '1 day waiting';
    return '$days days waiting';
  }

  @override
  Widget build(BuildContext context) {
    final route = FeedRouting.adaptTargetRoute(
      question.targetRoute,
      currentPath: GoRouterState.of(context).uri.path,
    );
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.r12),
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const _SignalEyebrow(
                    icon: Icons.help_outline_rounded,
                    label: 'AWAITING INSTITUTIONAL RESPONSE',
                  ),
                  const Spacer(),
                  Text(
                    _waitingLabel(),
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                question.preview.isEmpty
                    ? 'Public question'
                    : question.preview,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if ((question.publicSpaceName ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'In ${question.publicSpaceName!}',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//   RESPONSIVENESS OBSERVATION
// ─────────────────────────────────────────────────────────────────────

/// Per-institution observed response activity. Never a ranking,
/// never a score. Surfaces a count, a median latency, and a recency
/// timestamp — all observational, all derived from real replies.
class ResponsivenessObservationCard extends StatelessWidget {
  const ResponsivenessObservationCard({super.key, required this.row});

  final ResponsivenessRow row;

  String _medianLabel() {
    final h = row.medianResponseHours;
    if (h == null) return '';
    if (h < 1) {
      final mins = (h * 60).round();
      return 'median ${mins}m';
    }
    if (h < 24) return 'median ${h.toStringAsFixed(1)}h';
    final days = h / 24;
    return 'median ${days.toStringAsFixed(1)}d';
  }

  String _lastLabel() {
    final at = row.lastRespondedAt;
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return 'last ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'last ${diff.inHours}h';
    if (diff.inDays < 7) return 'last ${diff.inDays}d';
    return 'last ${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final median = _medianLabel();
    final last = _lastLabel();
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        onTap: row.institutionSlug.isEmpty
            ? null
            : () => context.push('/institutions/${row.institutionSlug}'),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.r12),
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SignalEyebrow(
                icon: Icons.timeline_outlined,
                label: 'OBSERVED RESPONSE ACTIVITY',
              ),
              const SizedBox(height: AuraSpace.s8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.institutionName.isEmpty
                          ? 'Institution'
                          : row.institutionName,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.ink,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (row.verified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 12,
                      color: AuraSurface.accentText,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${row.recentResponseCount} '
                '${row.recentResponseCount == 1 ? 'reply' : 'replies'} observed',
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (median.isNotEmpty || last.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  [median, last].where((s) => s.isNotEmpty).join(' · '),
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//   RELATED INSTITUTION STRIP
// ─────────────────────────────────────────────────────────────────────

/// Horizontal strip of institutions that share parent discussions with
/// the source institution. Each chip carries the shared-parent count
/// — "appeared in N of the same discussions" — and routes to the
/// institution profile.
class RelatedInstitutionStrip extends StatelessWidget {
  const RelatedInstitutionStrip({super.key, required this.rows});

  final List<RelatedInstitutionRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(width: AuraSpace.s8),
        itemBuilder: (_, i) => _RelatedChip(row: rows[i]),
      ),
    );
  }
}

class _RelatedChip extends StatelessWidget {
  const _RelatedChip({required this.row});

  final RelatedInstitutionRow row;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r10),
        onTap: row.institutionSlug.isEmpty
            ? null
            : () => context.push('/institutions/${row.institutionSlug}'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.institutionName.isEmpty
                        ? 'Institution'
                        : row.institutionName,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (row.verified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 11,
                      color: AuraSurface.accentText,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'shared ${row.sharedParentCount} '
                '${row.sharedParentCount == 1 ? 'discussion' : 'discussions'}',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.faint,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//   SHARED EYEBROW
// ─────────────────────────────────────────────────────────────────────

class _SignalEyebrow extends StatelessWidget {
  const _SignalEyebrow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: AuraSurface.divider.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AuraSurface.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}
