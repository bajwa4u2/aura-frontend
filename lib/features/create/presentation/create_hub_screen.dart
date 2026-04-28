import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class CreateHubScreen extends StatelessWidget {
  const CreateHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s20,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: [
              _CreateHero(),
              const SizedBox(height: AuraSpace.s28),
              const _CreateSection(
                title: 'Writing',
                items: [
                  _CreateActionData(
                    title: 'New work',
                    subtitle: 'Begin a piece of writing or long-form content.',
                    icon: Icons.edit_note_rounded,
                    route: '/compose',
                  ),
                  _CreateActionData(
                    title: 'With media',
                    subtitle:
                        'Open composition with image or video attachment.',
                    icon: Icons.perm_media_outlined,
                    route: '/compose',
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s20),
              const _CreateSection(
                title: 'Messages',
                items: [
                  _CreateActionData(
                    title: 'Conversation',
                    subtitle:
                        'Begin a direct private exchange with one person.',
                    icon: Icons.chat_bubble_outline_rounded,
                    route: '/me/correspondence/create/conversation',
                  ),
                  _CreateActionData(
                    title: 'Space',
                    subtitle: 'Form a shared room with clear membership.',
                    icon: Icons.groups_outlined,
                    route: '/me/correspondence/create/space',
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s20),
              const _CreateSection(
                title: 'System',
                items: [
                  _CreateActionData(
                    title: 'Claim audit',
                    subtitle: 'Open the AI-powered claim audit surface.',
                    icon: Icons.fact_check_outlined,
                    route: '/ai/claim-audit',
                  ),
                  _CreateActionData(
                    title: 'Announcement',
                    subtitle:
                        'Publish an official institution or platform notice.',
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

class _CreateHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s20,
        AuraSpace.s24,
        AuraSpace.s20,
        AuraSpace.s24,
      ),
      decoration: BoxDecoration(
        gradient: AuraGradients.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
        boxShadow: AuraShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create', style: AuraText.headline),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  'Start something — writing, a message, or a platform notice.',
                  style: AuraText.body.copyWith(
                    color: AuraSurface.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AuraGradients.accent,
              borderRadius: BorderRadius.circular(AuraRadius.r14),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

class _CreateSection extends StatelessWidget {
  const _CreateSection({required this.title, required this.items});

  final String title;
  final List<_CreateActionData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AuraSpace.s4,
            bottom: AuraSpace.s12,
          ),
          child: Text(
            title,
            style: AuraText.label.copyWith(
              color: AuraSurface.faint,
              letterSpacing: 0.8,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
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
                    const SizedBox(height: AuraSpace.s10),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(data.route),
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s16),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
            boxShadow: AuraShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  data.icon,
                  size: AuraIconSize.sm,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              Text(
                data.title,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AuraSpace.s6),
              Text(
                data.subtitle,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              Row(
                children: [
                  Text(
                    'Open',
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AuraSurface.accentText,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AuraSurface.accentText,
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
