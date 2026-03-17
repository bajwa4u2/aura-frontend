import 'package:flutter/material.dart';

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
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s16,
                vertical: AuraSpace.s16,
              ),
              children: const [
                _ActivityHeader(),
                SizedBox(height: AuraSpace.s16),
                _ActivityTile(
                  icon: Icons.reply_outlined,
                  title: 'Amina replied to your post',
                  subtitle: 'This deserves a deeper response.',
                  time: '2m ago',
                ),
                _ActivityTile(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'David followed you',
                  subtitle: 'View profile',
                  time: '10m ago',
                ),
                _ActivityTile(
                  icon: Icons.mail_outline,
                  title: 'You were invited to a space',
                  subtitle: 'Governance & Ethics',
                  time: '1h ago',
                ),
                _ActivityTile(
                  icon: Icons.check_circle_outline,
                  title: 'Your post was published',
                  subtitle: 'Tap to view',
                  time: '2h ago',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w700,
              ) ??
              const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AuraSurface.ink,
              ),
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'Signals around your writing, presence, and correspondence.',
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AuraSpace.s14,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AuraSurface.divider),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AuraSurface.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Icon(
                icon,
                size: 18,
                color: AuraSurface.ink,
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
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