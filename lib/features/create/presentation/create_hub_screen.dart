import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class CreateHubScreen extends StatelessWidget {
  const CreateHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      
      body: Padding(
        padding: const EdgeInsets.all(AuraSpace.md),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: AuraSpace.md,
          mainAxisSpacing: AuraSpace.md,
          children: [

            /// POST
            _CreateTile(
              
              icon: Icons.edit_outlined,
              onTap: () {
                context.go('/compose');
              },
            ),

            /// MEDIA
            _CreateTile(
              
              icon: Icons.image_outlined,
              onTap: () {
                context.go('/compose');
              },
            ),

            /// CLAIM AUDIT
            _CreateTile(
              
              icon: Icons.fact_check_outlined,
              onTap: () {
                context.go('/ai/claim-audit');
              },
            ),

            /// ANNOUNCEMENT
            _CreateTile(
              
              icon: Icons.campaign_outlined,
              onTap: () {
                context.go('/announcements/create');
              },
            ),

            /// NEW CONVERSATION
            _CreateTile(
              
              icon: Icons.forum_outlined,
              onTap: () {
                context.go('/me/correspondence/create/conversation');
              },
            ),

            /// SHARED SPACE
            _CreateTile(
              
              icon: Icons.groups_outlined,
              onTap: () {
                context.go('/me/correspondence/create/space');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _CreateTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: AuraSpace.sm),
          Text(
            title,
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}