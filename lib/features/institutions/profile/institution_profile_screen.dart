import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/document_scaffold.dart';

class InstitutionProfileScreen extends StatelessWidget {
  const InstitutionProfileScreen({super.key});

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AuraText.body.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: AuraText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AuraSurface.muted,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AuraText.body)),
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
              border: Border.all(color: AuraSurface.divider),
              borderRadius: BorderRadius.circular(AuraRadius.card),
            ),
            padding: const EdgeInsets.all(AuraSpace.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AuraSpace.s8),
                Text(detail, style: AuraText.body),
                const SizedBox(height: AuraSpace.s12),
                Text(
                  status,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? AuraSurface.ink : AuraSurface.muted,
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
            'Institution profile',
            style: (Theme.of(context).textTheme.headlineMedium ?? AuraText.body)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 30),
          ),
          const SizedBox(height: AuraSpace.s10),
          const Text(
            'This is the institution-facing profile workspace. Public institution identity, profile presentation, and institution-specific settings should be managed here, separate from member profile screens.',
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
          const SizedBox(height: AuraSpace.s12),
          _infoRow('Surface', 'Institution-only'),
          _infoRow('Public identity', 'Dedicated institution profile route'),
          _infoRow('Member profile flow', 'Separated'),
          _infoRow(
            'Editing workflow',
            'Placeholder until institution profile editing is connected',
          ),
        ],
      ),
    );
  }

  Widget _actionsCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Institution profile actions'),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s12,
            runSpacing: AuraSpace.s12,
            children: [
              _actionTile(
                title: 'Identity settings',
                detail:
                    'Institution name, description, visual identity, and public-facing profile details should be managed here.',
                status: 'Placeholder',
              ),
              _actionTile(
                title: 'Public profile controls',
                detail:
                    'Controls for how the institution appears publicly should remain attached to the institution branch, not the member profile branch.',
                status: 'Placeholder',
              ),
              _actionTile(
                title: 'Domain alignment',
                detail:
                    'Domain-linked identity and public institutional trust signals should connect here with the institution domain workflow.',
                status: 'Go to domains',
                onTap: () => context.go('/institution/domains'),
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
          const SizedBox(height: AuraSpace.s12),
          const Text(
            'Institution identity should not be edited through personal member profile surfaces. This route protects that separation now, so future institution profile tools can be built on the correct branch without leakage.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution profile'),
          const SizedBox(height: AuraSpace.s10),
          Doc.meta('Dedicated profile workspace for institutional accounts.'),
          Doc.lede(
            'This route is reserved for institution identity, public profile presentation, and profile-specific controls.',
          ),
          const SizedBox(height: AuraSpace.s12),
          _heroCard(context),
          const SizedBox(height: AuraSpace.s12),
          _overviewCard(),
          const SizedBox(height: AuraSpace.s12),
          _actionsCard(context),
          const SizedBox(height: AuraSpace.s12),
          _notesCard(),
        ],
      ),
    );
  }
}
