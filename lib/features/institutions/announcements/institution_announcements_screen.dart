import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/document_scaffold.dart';

class InstitutionAnnouncementsScreen extends StatelessWidget {
  const InstitutionAnnouncementsScreen({super.key});

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AuraText.body.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AuraSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: AuraText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: AuraText.body),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required String title,
    required String detail,
    required String status,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return SizedBox(
      width: 320,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: EdgeInsets.all(AuraSpace.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AuraSpace.s8),
                Text(detail, style: AuraText.body),
                SizedBox(height: AuraSpace.s12),
                Text(
                  status,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black87 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution announcements',
            style: (Theme.of(context).textTheme.headlineMedium ?? AuraText.body)
                .copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 30,
            ),
          ),
          SizedBox(height: AuraSpace.s10),
          Text(
            'This is the institutional announcements workspace. Official announcements should be created, reviewed, and managed here, separate from the public member announcements flow.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }

  Widget _overviewCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Workspace status'),
          SizedBox(height: AuraSpace.s12),
          _infoRow('Surface', 'Institution-only'),
          _infoRow('Public member feed', 'Separated'),
          _infoRow('Publishing flow', 'Placeholder until institutional workflow is built'),
          _infoRow('Moderation posture', 'Institutional review and record-first'),
        ],
      ),
    );
  }

  Widget _actionsCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Institution announcement actions'),
          SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s12,
            runSpacing: AuraSpace.s12,
            children: [
              _actionTile(
                title: 'Draft announcement',
                detail:
                    'Create official institution-facing announcements from a dedicated publishing flow.',
                status: 'Placeholder',
              ),
              _actionTile(
                title: 'Published announcements',
                detail:
                    'Review the institution’s published announcements archive here once the dedicated backend flow is connected.',
                status: 'Placeholder',
              ),
              _actionTile(
                title: 'Announcement review',
                detail:
                    'Institution review, approval, and publishing responsibility should live here rather than in public member tools.',
                status: 'Placeholder',
              ),
              _actionTile(
                title: 'Back to dashboard',
                detail:
                    'Return to the institution dashboard and continue through other institution-only tools.',
                status: 'Available now',
                onTap: () => context.go('/institution/dashboard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notesCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Why this screen exists'),
          SizedBox(height: AuraSpace.s12),
          Text(
            'Institution announcements should not fall into the same branch as public member reading surfaces. This screen keeps the route, identity, and future publishing workflow institution-specific from the start.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution announcements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution announcements'),
          SizedBox(height: AuraSpace.s10),
          Doc.meta('Dedicated announcements workspace for institutional accounts.'),
          Doc.lede(
            'This route is reserved for official institution announcements and should remain separate from public member announcement screens.',
          ),
          SizedBox(height: AuraSpace.s12),
          _heroCard(context),
          SizedBox(height: AuraSpace.s12),
          _overviewCard(),
          SizedBox(height: AuraSpace.s12),
          _actionsCard(context),
          SizedBox(height: AuraSpace.s12),
          _notesCard(),
        ],
      ),
    );
  }
}