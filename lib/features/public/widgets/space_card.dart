import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

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

/// Curated horizontal strip of public spaces for the home surface.
///
/// Phase 1: hardcoded topical seeds that route to the existing search
/// surface. This is a deliberate, honest stand-in until the public
/// spaces backend ships — the topics are real discourse spines (civic,
/// climate, tech, education, regional) so users see calibrated
/// destinations rather than placeholders.
class PublicSpacesStrip extends StatelessWidget {
  const PublicSpacesStrip({super.key});

  static const _seeds = <_SpaceSeed>[
    _SpaceSeed(
      title: 'Civic',
      description: 'Public policy, governance, and accountability.',
      icon: Icons.account_balance_outlined,
      query: 'civic',
    ),
    _SpaceSeed(
      title: 'Climate',
      description: 'Climate response, environment, and energy.',
      icon: Icons.eco_outlined,
      query: 'climate',
    ),
    _SpaceSeed(
      title: 'Technology',
      description: 'Software, infrastructure, and the public web.',
      icon: Icons.memory_rounded,
      query: 'technology',
    ),
    _SpaceSeed(
      title: 'Education',
      description: 'Schools, research, and learning systems.',
      icon: Icons.school_outlined,
      query: 'education',
    ),
    _SpaceSeed(
      title: 'Health',
      description: 'Public health, care systems, and advisories.',
      icon: Icons.local_hospital_outlined,
      query: 'health',
    ),
    _SpaceSeed(
      title: 'Local',
      description: 'Discussions anchored in your region.',
      icon: Icons.place_outlined,
      query: 'local',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s2),
        separatorBuilder: (_, __) => const SizedBox(width: AuraSpace.s10),
        itemCount: _seeds.length,
        itemBuilder: (context, i) {
          final s = _seeds[i];
          return SpaceCard(
            title: s.title,
            description: s.description,
            icon: s.icon,
            onTap: () => context.push('/search?q=${Uri.encodeQueryComponent(s.query)}'),
          );
        },
      ),
    );
  }
}

class _SpaceSeed {
  const _SpaceSeed({
    required this.title,
    required this.description,
    required this.icon,
    required this.query,
  });

  final String title;
  final String description;
  final IconData icon;
  final String query;
}
