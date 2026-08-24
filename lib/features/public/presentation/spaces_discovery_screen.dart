import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../discover/data/discover_repository.dart';
import '../../discover/widgets/discover_domain_cards.dart';

/// SPACES DISCOVERY — participation contexts, from the backend authority.
///
/// This screen used to render a hardcoded client registry: ten entries
/// compiled into the app, with no activity, no follow state and no idea which
/// of them the backend had ever heard of. Four of the ten existed only here,
/// so the directory offered contexts that were real on this screen and
/// nowhere else.
///
/// The registry's own doctrine named this migration — "when a backend
/// discovery endpoint ships, the provider swaps to call it and this registry
/// becomes the fallback" — and the four missing Spaces have since been seeded,
/// so the backend now holds the whole intended universe. It is the authority
/// here: what is discoverable, in what order, with what participation.
///
/// Deliberately NOT capped at today's ten. The endpoint pages, and this asks
/// for more than the landing preview because a domain destination is where
/// someone goes to see everything they could take part in.
class SpacesDiscoveryScreen extends ConsumerStatefulWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  ConsumerState<SpacesDiscoveryScreen> createState() =>
      _SpacesDiscoveryScreenState();
}

/// The domain destination shows everything eligible, including Spaces the
/// person already follows — unlike the landing preview, whose job is to
/// expand the horizon past them.
final _allSpacesProvider = FutureProvider.autoDispose<
    DiscoverPage<DiscoveredSpace>>((ref) async {
  return ref
      .read(discoverRepositoryProvider)
      .spaces(limit: 50, includeFollowed: true);
});

class _SpacesDiscoveryScreenState extends ConsumerState<SpacesDiscoveryScreen> {
  @override
  Widget build(BuildContext context) {
    final page = ref.watch(_allSpacesProvider);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_allSpacesProvider),
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            const SizedBox(height: AuraSpace.s8),
            const Text('Spaces', style: AuraText.display),
            const SizedBox(height: AuraSpace.s6),
            Text(
              'Public contexts for continuing conversation. Follow one to '
              'keep up with it, or open it to take part.',
              style: AuraText.body
                  .copyWith(color: AuraSurface.muted, height: 1.5),
            ),
            const SizedBox(height: AuraSpace.s20),
            page.when(
              loading: () => const AuraProductState(
                state: ProductState.loading,
              ),
              error: (_, __) => AuraProductState(
                state: ProductState.retryableError,
                headline: 'Spaces could not be loaded',
                action: AuraSecondaryButton(
                  label: ProductLabels.of(ProductAction.retry),
                  onPressed: () => ref.invalidate(_allSpacesProvider),
                  icon: Icons.refresh_rounded,
                ),
              ),
              data: (data) {
                if (data.isEmpty) {
                  return const AuraProductState(
                    state: ProductState.empty,
                    headline: 'No Spaces to show yet',
                    detail: 'Public contexts appear here as they open.',
                  );
                }
                return LayoutBuilder(
                  builder: (context, c) {
                    // Two-up once there is room; the tiles carry activity, so
                    // they need more width than a directory row.
                    final columns = c.maxWidth >= 900 ? 2 : 1;
                    if (columns == 1) {
                      return Column(
                        children: [
                          for (final s in data.items) ...[
                            SpaceEnvironmentTile(space: s),
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
                        for (final s in data.items)
                          SizedBox(
                            width: width,
                            child: SpaceEnvironmentTile(space: s),
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
