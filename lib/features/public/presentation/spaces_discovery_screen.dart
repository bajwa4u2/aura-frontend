import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../institutions/ui/institution_ds.dart';
import '../data/public_spaces_registry.dart';

/// Discovery screen at `/spaces`.
///
/// Public-UX Phase 2: a real list of public discourse spaces. Each tile
/// routes to `/spaces/:slug`. No tabs / no advanced filters in this
/// phase — the registry is small enough to render as a simple grid,
/// and adding tabs would invent UX the data doesn't yet justify.
class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(publicSpacesProvider);

    return AuraScaffold(
      showHeader: false,
      body: InsScreen(
        children: [
          const InsModeHeader(
            title: 'Spaces',
            description:
                'Topical and regional discourse environments. Public-first.',
          ),
          const InsModeHeaderGap(),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two-column on phones, three on tablets, four on desktop.
              final w = constraints.maxWidth;
              final cols = w >= 1100 ? 4 : (w >= 760 ? 3 : 2);
              const gap = AuraSpace.s12;
              final tileWidth = (w - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final s in spaces)
                    SizedBox(
                      width: tileWidth,
                      child: _SpaceListTile(
                        name: s.name,
                        description: s.description,
                        icon: s.icon,
                        onTap: () => context.push('/spaces/${s.slug}'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SpaceListTile extends StatelessWidget {
  const _SpaceListTile({
    required this.name,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s16),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, size: 20, color: AuraSurface.accentText),
              ),
              const SizedBox(height: AuraSpace.s12),
              Text(
                name,
                style: AuraText.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AuraSurface.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
