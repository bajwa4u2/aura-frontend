import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../models.dart';
import '../providers.dart';
import 'continuity_cards.dart';

/// Composite continuity panel for a sector or an institution.
///
/// Surfaces three observed signals from the
/// `DiscourseIntelligenceService` aggregations:
///   * Ongoing public discussions
///   * Questions awaiting institutional response
///   * Observed response activity
///
/// Each section self-collapses when its provider has nothing to show;
/// the whole panel collapses when every section is empty. There is
/// never an "empty metric box" or a "0 trending topics" placeholder —
/// quiet sectors produce zero chrome.
///
/// The panel is intentionally observational: section headers describe
/// what the data is ("Observed from recent public activity") rather
/// than ranking it. The brief is explicit that this is civic memory,
/// not engagement analytics.
class DiscourseContinuityPanel extends ConsumerWidget {
  const DiscourseContinuityPanel({
    super.key,
    this.institutionClass,
    this.institutionId,
    this.issueLimit = 3,
    this.unansweredLimit = 3,
    this.responsivenessLimit = 3,
  });

  /// Restrict to discussions involving institutions in this curated
  /// class. Mutually compatible with `institutionId`.
  final String? institutionClass;

  /// Restrict to discussions involving this specific institution.
  /// Mutually compatible with `institutionClass`.
  final String? institutionId;

  final int issueLimit;
  final int unansweredLimit;
  final int responsivenessLimit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = DiscourseScopeArgs(
      institutionClass: institutionClass,
      institutionId: institutionId,
    );
    final issuesAsync = ref.watch(scopedDiscourseIssuesProvider(scope));
    final unansweredAsync = ref.watch(unansweredQuestionsProvider(scope));
    final responsivenessAsync = ref.watch(responsivenessProvider(scope));

    final issues = issuesAsync.maybeWhen(
      data: (p) => p.items,
      orElse: () => const <DiscourseIssue>[],
    );
    final unanswered = unansweredAsync.maybeWhen(
      data: (p) => p.items,
      orElse: () => const <UnansweredQuestion>[],
    );
    final responsiveness = responsivenessAsync.maybeWhen(
      data: (p) => p.items,
      orElse: () => const <ResponsivenessRow>[],
    );

    final showIssues = issues.isNotEmpty;
    final showUnanswered = unanswered.isNotEmpty;
    final showResponsiveness = responsiveness.isNotEmpty;

    if (!showIssues && !showUnanswered && !showResponsiveness) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(
          color: AuraSurface.divider.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(),
          if (showIssues) ...[
            const SizedBox(height: AuraSpace.s12),
            const _SectionHeading(
              icon: Icons.forum_outlined,
              label: 'Ongoing public discussions',
              subtitle: 'Observed from recent public activity.',
            ),
            const SizedBox(height: AuraSpace.s8),
            for (var i = 0;
                i < issues.take(issueLimit).length;
                i++) ...[
              OngoingIssueCard(issue: issues[i]),
              if (i < issues.take(issueLimit).length - 1)
                const SizedBox(height: AuraSpace.s8),
            ],
          ],
          if (showUnanswered) ...[
            const SizedBox(height: AuraSpace.s16),
            const _SectionHeading(
              icon: Icons.help_outline_rounded,
              label: 'Awaiting institutional response',
              subtitle:
                  'Public posts with replies but no institution response observed yet.',
            ),
            const SizedBox(height: AuraSpace.s8),
            for (var i = 0;
                i < unanswered.take(unansweredLimit).length;
                i++) ...[
              UnansweredQuestionCard(question: unanswered[i]),
              if (i < unanswered.take(unansweredLimit).length - 1)
                const SizedBox(height: AuraSpace.s8),
            ],
          ],
          if (showResponsiveness) ...[
            const SizedBox(height: AuraSpace.s16),
            const _SectionHeading(
              icon: Icons.timeline_outlined,
              label: 'Observed response activity',
              subtitle:
                  'Response activity is observational, not a ranking.',
            ),
            const SizedBox(height: AuraSpace.s8),
            for (var i = 0;
                i < responsiveness.take(responsivenessLimit).length;
                i++) ...[
              ResponsivenessObservationCard(row: responsiveness[i]),
              if (i < responsiveness.take(responsivenessLimit).length - 1)
                const SizedBox(height: AuraSpace.s8),
            ],
          ],
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: AuraSurface.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AuraSpace.s8),
        Expanded(
          child: Text(
            'Discourse continuity',
            style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AuraSurface.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AuraText.micro.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
