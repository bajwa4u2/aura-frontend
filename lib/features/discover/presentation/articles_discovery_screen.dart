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
import '../data/discover_repository.dart';
import '../widgets/discover_domain_cards.dart';

/// ARTICLES DISCOVERY — a reading surface.
///
/// This was a reverse-chronological dump of titles. It is now the same
/// editorial presentation the landing uses, ordered by the relevance the
/// Articles domain can honestly support: who wrote it, whether you have
/// responded to their work before, and how recent it is.
///
/// WHAT IT DOES NOT DO, AND WHY. It does not rank by subject matter, because
/// the Article model carries no topic or tag column. Inferring a subject from
/// title text would be invented truth wearing the clothes of relevance. When
/// Articles gain governed topics the way Posts already have them, the topic
/// affinity signal gains this domain and the ordering improves — no surface
/// here changes.
///
/// Built for a corpus, not for three: the endpoint pages, and this asks for a
/// page rather than everything.

final _articlesProvider =
    FutureProvider.autoDispose<DiscoverPage<DiscoveredArticle>>((ref) async {
  return ref.read(discoverRepositoryProvider).articles(limit: 30);
});

class ArticlesDiscoveryScreen extends ConsumerWidget {
  const ArticlesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(_articlesProvider);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_articlesProvider),
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            const SizedBox(height: AuraSpace.s8),
            const Text('Articles', style: AuraText.display),
            const SizedBox(height: AuraSpace.s6),
            Text(
              'Durable, authored writing — long-form thought that stays worth '
              'returning to.',
              style:
                  AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
            ),
            const SizedBox(height: AuraSpace.s20),
            page.when(
              loading: () =>
                  const AuraProductState(state: ProductState.loading),
              error: (_, __) => AuraProductState(
                state: ProductState.retryableError,
                headline: 'Articles could not be loaded',
                action: AuraSecondaryButton(
                  label: ProductLabels.of(ProductAction.retry),
                  onPressed: () => ref.invalidate(_articlesProvider),
                  icon: Icons.refresh_rounded,
                ),
              ),
              data: (data) {
                if (data.isEmpty) {
                  return const AuraProductState(
                    state: ProductState.empty,
                    headline: 'Nothing published yet',
                    detail: 'Articles appear here as people publish them.',
                  );
                }
                return LayoutBuilder(
                  builder: (context, c) {
                    // Reading columns, not a card grid: two-up once there is
                    // genuinely room for two comfortable measures.
                    final columns = c.maxWidth >= 1000 ? 2 : 1;
                    if (columns == 1) {
                      return Column(
                        children: [
                          for (final a in data.items)
                            ArticleEditorialCard(article: a),
                        ],
                      );
                    }
                    const gap = AuraSpace.s12;
                    final width = (c.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: 0,
                      children: [
                        for (final a in data.items)
                          SizedBox(
                            width: width,
                            child: ArticleEditorialCard(article: a),
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
