import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../institution_ontology/models.dart';
import '../../institution_ontology/providers.dart';
import '../data/discover_repository.dart';
import '../widgets/discover_domain_cards.dart';

/// INSTITUTIONS DISCOVERY — the institutional ecosystem, not a directory row.
///
/// The Discover landing keeps institutions deliberately restrained; this is
/// where they get room. Presences ordered by relevance — who the people you
/// follow follow, what an institution actually publishes about, and whether it
/// operates where you do — with verification carried as trust rather than as
/// rank.
///
/// THE 24-SECTOR ONTOLOGY LIVES HERE. It is the right place for it: a
/// classification wall on the general landing would make institutional
/// taxonomy Aura's acquisition premise, while here it is a genuine way to
/// explore an ecosystem by what an institution IS.
///
/// It also tells the truth about itself. Sector narrowing filters the eligible
/// set; it never ranks it, and it cannot reach past eligibility. When a sector
/// has no members the screen says so plainly instead of rendering an empty
/// grid that looks broken — which matters today, because no institution
/// currently carries a classification at all.
///
/// Built for an ecosystem of thousands: the endpoint pages, narrowing happens
/// server-side, and nothing here ranks or filters a corpus in the client.

final _selectedSectorProvider = StateProvider.autoDispose<String?>((ref) => null);

final _institutionsProvider = FutureProvider.autoDispose<
    DiscoverPage<DiscoveredInstitution>>((ref) async {
  final sector = ref.watch(_selectedSectorProvider);
  return ref.read(discoverRepositoryProvider).institutions(
        limit: 40,
        institutionClass: sector,
        // A domain destination shows the whole ecosystem, including the
        // institutions you already follow — unlike the landing preview, whose
        // job is to expand past them.
        includeFollowed: true,
      );
});

class InstitutionsDiscoveryScreen extends ConsumerWidget {
  const InstitutionsDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(_institutionsProvider);
    final sector = ref.watch(_selectedSectorProvider);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_institutionsProvider),
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            const SizedBox(height: AuraSpace.s8),
            const Text('Institutions', style: AuraText.display),
            const SizedBox(height: AuraSpace.s6),
            Text(
              'Organisations participating publicly on Aura, under their '
              'official identity.',
              style:
                  AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
            ),
            const SizedBox(height: AuraSpace.s20),
            const _SectorFilter(),
            const SizedBox(height: AuraSpace.s16),
            page.when(
              loading: () =>
                  const AuraProductState(state: ProductState.loading),
              error: (_, __) => AuraProductState(
                state: ProductState.retryableError,
                headline: 'Institutions could not be loaded',
                action: AuraSecondaryButton(
                  label: ProductLabels.of(ProductAction.retry),
                  onPressed: () => ref.invalidate(_institutionsProvider),
                  icon: Icons.refresh_rounded,
                ),
              ),
              data: (data) {
                if (data.isEmpty) {
                  // A sector with no members is a truthful answer about the
                  // corpus, not a failure — and a different sentence from
                  // "there are no institutions at all".
                  return AuraProductState(
                    state: ProductState.empty,
                    headline: sector == null
                        ? 'No institutions to show yet'
                        : 'No institutions in this sector yet',
                    detail: sector == null
                        ? 'Institutions appear here as they join and publish.'
                        : 'Clear the sector to see every institution.',
                  );
                }
                return LayoutBuilder(
                  builder: (context, c) {
                    final columns = c.maxWidth >= 900 ? 2 : 1;
                    if (columns == 1) {
                      return Column(
                        children: [
                          for (final i in data.items) ...[
                            InstitutionPresenceCard(institution: i),
                            const SizedBox(height: AuraSpace.s10),
                          ],
                        ],
                      );
                    }
                    const gap = AuraSpace.s12;
                    final width = (c.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final i in data.items)
                          SizedBox(
                            width: width,
                            child: InstitutionPresenceCard(institution: i),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Sector narrowing, from the public curated taxonomy.
///
/// Collapses entirely when the ontology is unavailable — the ecosystem is
/// still browsable without it, so a broken filter should not become a broken
/// page.
class _SectorFilter extends ConsumerWidget {
  const _SectorFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ontology = ref.watch(institutionOntologyProvider);
    final classes =
        ontology.valueOrNull?.classes ?? const <InstitutionClassDef>[];
    if (classes.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(_selectedSectorProvider);

    Widget chip(String label, bool isSelected, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s12,
              vertical: AuraSpace.s8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AuraSurface.accentSoft : AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(
                color: isSelected
                    ? AuraSurface.accent.withValues(alpha: 0.4)
                    : AuraSurface.divider,
              ),
            ),
            child: Text(
              label,
              style: AuraText.small.copyWith(
                color: isSelected ? AuraSurface.ink : AuraSurface.muted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Browse by sector', style: AuraText.title),
        const SizedBox(height: 2),
        Text(
          'Each sector narrows to the institutions working in it.',
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
        const SizedBox(height: AuraSpace.s12),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            chip('All', selected == null,
                () => ref.read(_selectedSectorProvider.notifier).state = null),
            for (final c in classes)
              chip(
                c.label,
                selected == c.id,
                () => ref.read(_selectedSectorProvider.notifier).state =
                    selected == c.id ? null : c.id,
              ),
          ],
        ),
      ],
    );
  }
}
