import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/document_scaffold.dart';

class InstitutionCorrespondenceScreen extends StatelessWidget {
  const InstitutionCorrespondenceScreen({super.key});

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
            width: 148,
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
            'Institution correspondence',
            style: (Theme.of(context).textTheme.headlineMedium ?? AuraText.body)
                .copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 30,
            ),
          ),
          SizedBox(height: AuraSpace.s10),
          Text(
            'This is the institutional correspondence workspace. Official institutional exchange should be handled here, separate from the signed-in member correspondence flow.',
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
          _infoRow('Member mailbox', 'Separated'),
          _infoRow('Official communication', 'Reserved for institution routes'),
          _infoRow('Record posture', 'Continuity, traceability, and institutional memory'),
        ],
      ),
    );
  }

  Widget _actionsCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Institution correspondence actions'),
          SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s12,
            runSpacing: AuraSpace.s12,
            children: [
              _actionTile(
                title: 'Inbox',
                detail:
                    'Institution-level incoming correspondence should appear here once the dedicated routing and backend flow are connected.',
                status: 'Placeholder',
              ),
              _actionTile(
                title: 'Outbox',
                detail:
                    'Official institution messages, statements, and outgoing correspondence should be tracked here.',
                status: 'Placeholder',
              ),
              _actionTile(
                title: 'Drafts',
                detail:
                    'Institution drafts should remain separate from personal member drafts and private author writing.',
                status: 'Placeholder',
              ),
              _actionTile(
                title: 'Records',
                detail:
                    'Important institutional exchanges should be preserved in a durable record layer tied to the institution branch.',
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
            'Institution correspondence should not inherit the member mailbox by accident. This screen keeps the route and future workflow institution-specific, so official exchange can later be built with the right permissions, records, and continuity.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution correspondence',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution correspondence'),
          SizedBox(height: AuraSpace.s10),
          Doc.meta('Dedicated correspondence workspace for institutional accounts.'),
          Doc.lede(
            'This route is reserved for official institutional exchange and should remain separate from member correspondence screens.',
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