import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class CreateHubScreen extends StatelessWidget {
  const CreateHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Create',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: const [
              _CreateLead(),
              SizedBox(height: AuraSpace.s20),
              _CreateSection(
                title: 'Writing',
                items: [
                  _CreateActionData(
                    title: 'Work',
                    subtitle: 'Begin a new piece.',
                    icon: Icons.edit_outlined,
                    route: '/compose',
                  ),
                  _CreateActionData(
                    title: 'Media',
                    subtitle: 'Open composition with media.',
                    icon: Icons.perm_media_outlined,
                    route: '/compose',
                  ),
                ],
              ),
              SizedBox(height: AuraSpace.s16),
              _CreateSection(
                title: 'Correspondence',
                items: [
                  _CreateActionData(
                    title: 'Conversation',
                    subtitle: 'Begin a direct exchange.',
                    icon: Icons.forum_outlined,
                    route: '/me/correspondence/create/conversation',
                  ),
                  _CreateActionData(
                    title: 'Space',
                    subtitle: 'Form a shared place.',
                    icon: Icons.groups_outlined,
                    route: '/me/correspondence/create/space',
                  ),
                ],
              ),
              SizedBox(height: AuraSpace.s16),
              _CreateSection(
                title: 'System',
                items: [
                  _CreateActionData(
                    title: 'Claim audit',
                    subtitle: 'Open the audit surface.',
                    icon: Icons.fact_check_outlined,
                    route: '/ai/claim-audit',
                  ),
                  _CreateActionData(
                    title: 'Announcement',
                    subtitle: 'Publish an official notice.',
                    icon: Icons.campaign_outlined,
                    route: '/announcements/create',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateLead extends StatelessWidget {
  const _CreateLead();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create',
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Choose what to begin.',
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateSection extends StatelessWidget {
  const _CreateSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_CreateActionData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s10),
          child: Text(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    Expanded(child: _CreateActionCard(data: items[i])),
                    if (i != items.length - 1)
                      const SizedBox(width: AuraSpace.s12),
                  ],
                ],
              );
            }

            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _CreateActionCard(data: items[i]),
                  if (i != items.length - 1)
                    const SizedBox(height: AuraSpace.s12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CreateActionCard extends StatelessWidget {
  const _CreateActionCard({required this.data});

  final _CreateActionData data;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      onTap: () => context.go(data.route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AuraSurface.elevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Icon(data.icon, size: 18, color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            data.title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(
            data.subtitle,
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s14),
          Row(
            children: [
              Text(
                'Open',
                style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AuraSpace.s6),
              const Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateActionData {
  const _CreateActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}
