import 'package:flutter/material.dart';

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
    return Row(
      children: [
        const Icon(
          Icons.admin_panel_settings_outlined,
          size: 16,
          color: AuraSurface.accent,
        ),
        const SizedBox(width: AuraSpace.s8),
        Text(
          'Admin communication workspace',
          style: AuraText.label.copyWith(
            color: AuraSurface.accent,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
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
            'Protected',
            style: AuraText.micro.copyWith(color: AuraSurface.warnInk),
          ),
        ),
      ],
    );
  }
}
