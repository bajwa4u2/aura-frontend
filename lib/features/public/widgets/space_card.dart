import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/public_spaces_registry.dart';

/// Compact tile for a public discourse space.
///
/// Phase 1 — the Aura backend does not yet expose a public spaces
/// discovery endpoint, so the home strip renders a curated list of
/// topical seeds (see [PublicSpacesStrip] below). When the public
/// spaces backend ships, the same widget binds 1:1 to whatever DTO
/// we end up with — only the data source changes.
class SpaceCard extends StatelessWidget {
  const SpaceCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.activitySummary,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  /// One-line summary like "12 active threads · 3 live now". Optional
  /// — when null, the line is omitted so the card stays calm.
  final String? activitySummary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, size: 18, color: AuraSurface.accentText),
              ),
              const SizedBox(height: AuraSpace.s10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraText.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AuraSurface.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.4,
                ),
              ),
              if (activitySummary != null) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(
                  activitySummary!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of public spaces for the home surface.
///
/// Phase 2: real spaces — each tile routes to `/spaces/:slug`, which
/// renders a real discourse-scoped space detail screen. The data source
/// is `publicSpacesProvider` (curated registry today; backend later).
class PublicSpacesStrip extends ConsumerWidget {
  const PublicSpacesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(publicSpacesProvider);
    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s2),
        separatorBuilder: (_, __) => const SizedBox(width: AuraSpace.s10),
        itemCount: spaces.length + 1,
        itemBuilder: (context, i) {
          if (i == spaces.length) {
            return _AllSpacesTile(onTap: () => context.push('/spaces'));
          }
          final s = spaces[i];
          return SpaceCard(
            title: s.name,
            description: s.description,
            icon: s.icon,
            onTap: () => context.push('/spaces/${s.slug}'),
          );
        },
      ),
    );
  }
}

class _AllSpacesTile extends StatelessWidget {
  const _AllSpacesTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 18,
                color: AuraSurface.muted,
              ),
              SizedBox(height: AuraSpace.s10),
              Text(
                'See all spaces',
                style: AuraText.body,
              ),
              SizedBox(height: 2),
              Text(
                'Topical and regional discourse environments.',
                style: AuraText.muted,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
