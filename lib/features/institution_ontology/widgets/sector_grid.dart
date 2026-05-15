import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../models.dart';
import '../providers.dart';

/// Reusable Browse-by-sector grid.
///
/// Renders every curated Level-1 class from `institutionOntologyProvider`
/// as a tap-through card. Each card carries the class label, a tone-
/// matching icon, and the curated description. Tap → routes to
/// `/institutions/sector/:classId`.
///
/// Layout adapts: 4 columns at desktop, 3 at tablet-wide, 2 at narrow
/// tablet, 1 on mobile. No fake counts, no fabricated activity — this
/// is a pure ecosystem map, the route's own page is what surfaces the
/// real institutions.
class SectorGrid extends ConsumerWidget {
  const SectorGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ontologyAsync = ref.watch(institutionOntologyProvider);
    final ontology = ontologyAsync.valueOrNull ?? InstitutionOntology.empty;
    if (ontology.classes.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Desktop normalization — 5 cols at widescreen so the 24
        // curated classes lay out in ~5 visual rows instead of 6.
        // Below 1100 the previous 4-3-2-1 scale is preserved.
        final cols = w >= 1280
            ? 5
            : w >= 1000
                ? 4
                : w >= 760
                    ? 3
                    : w >= 540
                        ? 2
                        : 1;
        return Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            for (final c in ontology.classes)
              SizedBox(
                width: (w - (AuraSpace.s10 * (cols - 1))) / cols,
                child: SectorCard(classDef: c),
              ),
          ],
        );
      },
    );
  }
}

/// Single sector entry. Visual treatment is intentionally infrastructural —
/// outline card + small accent icon + class label + description excerpt.
/// No counts; no fake hover sparkle. Calm civic tone.
class SectorCard extends StatelessWidget {
  const SectorCard({super.key, required this.classDef});

  final InstitutionClassDef classDef;

  IconData get _icon {
    switch (classDef.id) {
      case 'GOVERNMENT':
        return Icons.account_balance_outlined;
      case 'EDUCATIONAL':
        return Icons.school_outlined;
      case 'HEALTHCARE':
        return Icons.health_and_safety_outlined;
      case 'MEDIA':
        return Icons.newspaper_outlined;
      case 'NONPROFIT':
        return Icons.volunteer_activism_outlined;
      case 'COMMERCIAL':
        return Icons.apartment_outlined;
      case 'RESEARCH':
        return Icons.science_outlined;
      case 'JUDICIAL':
        return Icons.gavel_outlined;
      case 'EMERGENCY':
        return Icons.emergency_outlined;
      case 'RELIGIOUS':
        return Icons.temple_buddhist_outlined;
      case 'COMMUNITY':
        return Icons.diversity_3_outlined;
      case 'INTERNATIONAL':
        return Icons.public_outlined;
      case 'SCIENTIFIC':
        return Icons.biotech_outlined;
      case 'FINANCIAL':
        return Icons.account_balance_wallet_outlined;
      case 'CULTURAL':
        return Icons.museum_outlined;
      case 'ENVIRONMENTAL':
        return Icons.eco_outlined;
      case 'TRANSPORTATION':
        return Icons.directions_transit_outlined;
      case 'ADVOCACY':
        return Icons.campaign_outlined;
      case 'TECHNOLOGY':
        return Icons.memory_outlined;
      case 'PUBLIC_SAFETY':
        return Icons.shield_outlined;
      case 'COMMUNICATIONS':
        return Icons.cell_tower_outlined;
      case 'ENERGY':
        return Icons.bolt_outlined;
      case 'INFRASTRUCTURE':
        return Icons.engineering_outlined;
      default:
        return Icons.workspaces_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.r14),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        onTap: () => context.push('/institutions/sector/${classDef.id}'),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AuraSurface.accentSoft,
                      borderRadius: BorderRadius.circular(AuraRadius.r10),
                      border: Border.all(
                        color:
                            AuraSurface.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _icon,
                      size: 18,
                      color: AuraSurface.accentText,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Text(
                      classDef.label,
                      style: AuraText.subtitle.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                classDef.description,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.4,
                ),
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
