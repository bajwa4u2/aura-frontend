import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import 'admin_ai_draft_panel.dart';
import 'admin_campaign_workflow.dart';
import 'admin_newsletter_lab.dart';

class AdminCommunicationWorkspace extends StatelessWidget {
  const AdminCommunicationWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AdminWorkspaceHeader(),
        const SizedBox(height: AuraSpace.s16),
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AuraSurface.accent.withValues(alpha: 0.35),
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: AuraSpace.s16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EmailCategoryGuide(),
              SizedBox(height: AuraSpace.s16),
              AdminNewsletterLab(),
              SizedBox(height: AuraSpace.s16),
              AdminAiDraftPanel(),
              SizedBox(height: AuraSpace.s16),
              AdminCampaignWorkflow(),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminWorkspaceHeader extends StatelessWidget {
  const _AdminWorkspaceHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 16,
              color: AuraSurface.accent,
            ),
            const SizedBox(width: AuraSpace.s8),
            Flexible(
              child: Text(
                'Email operations console',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraText.label.copyWith(
                  color: AuraSurface.accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AuraSurface.warnBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Admin only',
                style: AuraText.micro.copyWith(color: AuraSurface.warnInk),
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        const Text(
          'Compose, preview, and test every outbound email category from one place. '
          'Changes here affect real members. Use test sends before approving campaigns.',
          style: AuraText.muted,
        ),
      ],
    );
  }
}

// ── Email category reference guide ───────────────────────────────────────────

class _EmailCategoryGuide extends StatelessWidget {
  const _EmailCategoryGuide();

  static const _categories = <_CategoryRow>[
    _CategoryRow(
      icon: Icons.shield_outlined,
      label: 'Security / Auth',
      sender: 'AURA_SUPPORT',
      description:
          'Verify email, password reset, password changed, new device alerts. '
          'Always delivered — members cannot opt out.',
      protected: true,
    ),
    _CategoryRow(
      icon: Icons.support_agent_outlined,
      label: 'Support',
      sender: 'AURA_SUPPORT',
      description:
          'Support acknowledgements and follow-ups. '
          'Sent from the support inbox so members can reply directly.',
      protected: true,
    ),
    _CategoryRow(
      icon: Icons.campaign_outlined,
      label: 'Announcements',
      sender: 'AURA_HELLO',
      description:
          'Community and platform announcements. Respects member channel and frequency preferences.',
    ),
    _CategoryRow(
      icon: Icons.newspaper_outlined,
      label: 'Newsletter / Product updates',
      sender: 'AURA_HELLO',
      description:
          'Curated platform updates and newsletters. '
          'Always includes unsubscribe and manage-preferences links.',
    ),
    _CategoryRow(
      icon: Icons.inbox_outlined,
      label: 'Digest',
      sender: 'AURA_HELLO',
      description:
          'Daily or weekly summary of missed activity. '
          'Frequency is member-controlled and always includes opt-out links.',
    ),
    _CategoryRow(
      icon: Icons.chat_bubble_outline,
      label: 'Messages',
      sender: 'AURA_HELLO',
      description:
          'Transactional message-received and thread-invite notifications. '
          'Frequency follows member preferences.',
    ),
    _CategoryRow(
      icon: Icons.group_outlined,
      label: 'Social',
      sender: 'AURA_HELLO',
      description:
          'Follows, likes, replies, reposts, mentions. '
          'Members can set to digest or disable entirely.',
    ),
    _CategoryRow(
      icon: Icons.account_balance_outlined,
      label: 'Institutions',
      sender: 'AURA_HELLO',
      description:
          'Space and institution invitations. '
          'Sent instantly — members can adjust channel but not frequency.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('Email category guide', style: AuraText.subtitle),
              ),
              AuraStatusChip(
                label: 'Reference',
                backgroundColor: AuraSurface.infoBg,
                textColor: AuraSurface.infoInk,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          const Text(
            'Each outbound category has a fixed sender and respects member preferences differently.',
            style: AuraText.muted,
          ),
          const SizedBox(height: AuraSpace.s16),
          ..._categories.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s12),
              child: _CategoryTile(row: row),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.sender,
    required this.description,
    this.protected = false,
  });

  final IconData icon;
  final String label;
  final String sender;
  final String description;
  final bool protected;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.row});

  final _CategoryRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            row.icon,
            size: 16,
            color: AuraSurface.accentText,
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    row.label,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AuraSurface.subtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      row.sender,
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.faint,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  if (row.protected) ...[
                    const SizedBox(width: AuraSpace.s6),
                    const AuraStatusChip(
                      label: 'Transactional',
                      backgroundColor: AuraSurface.infoBg,
                      textColor: AuraSurface.infoInk,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(row.description, style: AuraText.muted),
            ],
          ),
        ),
      ],
    );
  }
}
