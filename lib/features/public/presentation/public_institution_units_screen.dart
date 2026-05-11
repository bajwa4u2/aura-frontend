import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../shared/identity/aura_identity_badge.dart';
import '../data/public_institutions_repository.dart';

/// Public listing of an institution's units (sub-entities).
///
/// Units inherit institutional trust: a unit under a verified
/// institution carries the same verified weight, signaled visually by
/// the verified badge in the page header. The unit cards themselves
/// don't repeat the badge — the trust attribution is upstream-only,
/// which keeps the visual hierarchy clean (institution = primary
/// identity, unit = scoped identity under that primary).
final publicInstitutionUnitsProvider =
    FutureProvider.family<PublicInstitutionUnitsPage, String>((ref, slug) {
  return ref.watch(publicInstitutionsRepositoryProvider).listUnits(slug);
});

class PublicInstitutionUnitsScreen extends ConsumerWidget {
  const PublicInstitutionUnitsScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicInstitutionUnitsProvider(slug));
    return AuraScaffold(
      showHeader: false,
      body: async.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading units…'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Could not load units',
              body: 'Try again in a moment.',
              action: AuraSecondaryButton(
                label: 'Retry',
                onPressed: () =>
                    ref.invalidate(publicInstitutionUnitsProvider(slug)),
              ),
            ),
          ),
        ),
        data: (page) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(page: page),
                    const SizedBox(height: AuraSpace.s20),
                    if (page.units.isEmpty)
                      AuraEmptyState(
                        title: 'No public units yet',
                        body:
                            'This institution hasn\'t exposed any sub-units '
                            'on its public surface. Operating divisions, '
                            'products, and chapters appear here when they '
                            'are marked public.',
                        icon: Icons.account_tree_outlined,
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth >= 960
                              ? 3
                              : constraints.maxWidth >= 640
                                  ? 2
                                  : 1;
                          return Wrap(
                            spacing: AuraSpace.s12,
                            runSpacing: AuraSpace.s12,
                            children: [
                              for (final u in page.units)
                                SizedBox(
                                  width: (constraints.maxWidth -
                                          (AuraSpace.s12 * (cols - 1))) /
                                      cols,
                                  child: _UnitCard(
                                    institutionSlug: page.institutionSlug,
                                    unit: u,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.page});
  final PublicInstitutionUnitsPage page;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.push('/institutions/${page.institutionSlug}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Back to ${page.institutionName}',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Units of ${page.institutionName}',
                style: AuraText.headline,
              ),
            ),
            if (page.institutionIsVerified)
              const AuraVerifiedInstitutionBadge(),
          ],
        ),
        const SizedBox(height: AuraSpace.s6),
        Text(
          'Operating divisions, products, and chapters under this '
          'institution. Each unit inherits the institution\'s trust '
          'context — verification flows downward.',
          style: AuraText.body.copyWith(
            color: AuraSurface.muted,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.institutionSlug,
    required this.unit,
  });
  final String institutionSlug;
  final PublicUnit unit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.r14),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        onTap: () => context.push(
          '/institutions/$institutionSlug/units/${unit.slug}',
        ),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.r14),
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _iconForType(unit.type),
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _labelForType(unit.type),
                    style: AuraText.micro.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                unit.name,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((unit.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  unit.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.45,
                  ),
                ),
              ],
              if (unit.locationLabel.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s8),
                Row(
                  children: [
                    Icon(Icons.place_outlined,
                        size: 12, color: AuraSurface.faint),
                    const SizedBox(width: 4),
                    Text(
                      unit.locationLabel,
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.faint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForType(String type) {
  switch (type.toUpperCase()) {
    case 'DEPARTMENT':
      return Icons.workspaces_outlined;
    case 'PRODUCT':
      return Icons.widgets_outlined;
    case 'TEAM':
      return Icons.group_work_outlined;
    case 'CHAPTER':
      return Icons.location_city_outlined;
    case 'PROGRAM':
      return Icons.flag_outlined;
    case 'BUREAU':
    case 'AGENCY':
      return Icons.account_balance_outlined;
    default:
      return Icons.hub_outlined;
  }
}

String _labelForType(String type) {
  final s = type.replaceAll('_', ' ');
  return s.isEmpty ? 'UNIT' : s.toUpperCase();
}
