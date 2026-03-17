import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s16,
          ),
          children: const [
            _SectionHeader(title: 'Activity'),

            SizedBox(height: AuraSpace.s12),

            _ActivityTile(
              title: 'Amina replied to your post',
              subtitle: '“This deserves a deeper response…”',
              time: '2m ago',
            ),

            _ActivityTile(
              title: 'David followed you',
              subtitle: 'View profile',
              time: '10m ago',
            ),

            _ActivityTile(
              title: 'You were invited to a space',
              subtitle: 'Governance & Ethics',
              time: '1h ago',
            ),

            _ActivityTile(
              title: 'Your post was published',
              subtitle: 'Tap to view',
              time: '2h ago',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AuraText.h3.copyWith(
        fontWeight: FontWeight.w700,
        color: AuraSurface.ink,
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AuraSpace.s12,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AuraSurface.divider),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 16),

            const SizedBox(width: AuraSpace.s12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AuraSurface.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AuraSpace.s8),

            Text(
              time,
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}