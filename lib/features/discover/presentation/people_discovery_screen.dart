import '../widgets/person_suggestion_card.dart';
import '../data/people_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// DISCOVER → PEOPLE = personalized human discovery, with search always
/// available (founder-frozen 2026-08-16). Suggestions come from the
/// canonical /v1/discover/people projection (deterministic, explainable,
/// privacy-safe); search remains its own always-available mechanism.
/// Reasons render quietly; no mechanics, no leaderboards, no "Creators".
class PeopleDiscoveryScreen extends ConsumerWidget {
  const PeopleDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(peopleDiscoveryProvider);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(peopleDiscoveryProvider),
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            const Text('People', style: AuraText.display),
            const SizedBox(height: AuraSpace.s6),
            Text(
              'Find people to follow and talk with.',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
            ),
            const SizedBox(height: AuraSpace.s14),
            // SEARCH ALWAYS AVAILABLE — intentional lookup is its own door.
            InkWell(
              onTap: () => context.push('/search'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16, vertical: AuraSpace.s12),
                decoration: BoxDecoration(
                  color: AuraSurface.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AuraSurface.muted),
                    const SizedBox(width: AuraSpace.s10),
                    Text('Search for someone…',
                        style:
                            AuraText.body.copyWith(color: AuraSurface.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            page.when(
              loading: () => const AuraProductState(
                  state: ProductState.loading, subject: ProductNoun.person),
              error: (e, _) => AuraProductState(
                state: ProductState.retryableError,
                subject: ProductNoun.person,
                detail: 'Search is still available above.',
                onRecover: () => ref.invalidate(peopleDiscoveryProvider),
              ),
              data: (data) {
                final suggestions = data.suggestions;
                if (suggestions.isEmpty) {
                  return const AuraProductState(
                    state: ProductState.empty,
                    subject: ProductNoun.person,
                    headline: 'No suggestions yet',
                    detail:
                        'As you follow people and take part in Spaces, Aura '
                        'gets better at suggesting people worth meeting. '
                        'Search is always available.',
                    icon: Icons.groups_outlined,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.coldStart
                          ? 'Active on Aura — a starting point while Aura '
                              'learns what matters to you'
                          : 'Suggested for you',
                      style: AuraText.title,
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    for (final s in suggestions) PersonSuggestionCard(suggestion: s),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
