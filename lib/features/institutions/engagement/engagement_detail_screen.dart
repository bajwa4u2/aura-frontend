import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_surface.dart';
import '../workspace/workspace_page.dart';
import 'question_record.dart';

/// ONE QUESTION OR ISSUE, AS ITS OWN PAGE (DD-43).
///
/// The Record page type. On wide screens a question opens beside the Desk
/// or the Questions list instead; this page is what a phone or a tablet, a
/// notification or a link opens. Its content is [QuestionRecord], the same
/// widget shown beside the list, so the two can never drift. Back names
/// where it goes: the Desk when it was opened from there, otherwise
/// Questions.
class EngagementDetailScreen extends StatelessWidget {
  const EngagementDetailScreen({
    super.key,
    required this.institutionId,
    required this.recordId,
  });

  final String institutionId;
  final String recordId;

  @override
  Widget build(BuildContext context) {
    String? from;
    try {
      from = GoRouterState.of(context).uri.queryParameters['from'];
    } catch (_) {
      // Shown outside a router (tests, previews): back goes to Questions.
    }
    final fromDesk = from == 'desk';
    return Material(
      color: AuraSurface.page,
      child: QuestionRecord(
        institutionId: institutionId,
        recordId: recordId,
        back: WorkspaceBack(
          label: fromDesk ? 'Desk' : 'Questions',
          path: fromDesk ? '/institution/$institutionId/desk' : '/institution/$institutionId/public-engagement',
        ),
      ),
    );
  }
}
