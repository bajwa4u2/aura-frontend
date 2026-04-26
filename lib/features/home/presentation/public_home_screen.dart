import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../feed/domain/post.dart';
import '../../feed/providers.dart';

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

class PublicHomeScreen extends ConsumerWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksAsync = ref.watch(feedProvider);

    return AuraScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const AuraGradientHeader(
                title: 'Aura Public Work',
                subtitle:
                    'A premium public surface for writing, publishing, and institutional trust signals.',
              ),
              const SizedBox(height: AuraSpace.s16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _PublicWorksHeader(context)),
                            const SizedBox(width: AuraSpace.s16),
                            Expanded(
                              child: _PublicCalloutColumn(
                                onSearch: () => context.go('/search'),
                                onInstitutions: () => context.go('/institutions'),
                                onJoin: () => context.go('/register'),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _PublicWorksHeader(context),
                            const SizedBox(height: AuraSpace.s16),
                            _PublicCalloutColumn(
                              onSearch: () => context.go('/search'),
                              onInstitutions: () => context.go('/institutions'),
                              onJoin: () => context.go('/register'),
                            ),
                          ],
                        );
                },
              ),
              const SizedBox(height: AuraSpace.s18),
              const AuraSectionHeader(
                title: 'Public work',
                subtitle: 'Recent writing and creations from the network.',
              ),
              const SizedBox(height: AuraSpace.s12),
              worksAsync.when(
                data: (posts) {
                  if (posts.isEmpty) {
                    return const AuraEmptyState(
                      title: 'No public work yet',
                      body:
                          'When people publish, their work will appear here with context and provenance.',
                      icon: Icons.public_outlined,
                    );
                  }

                  final show = posts.take(6).toList();

                  return Column(
                    children: [
                      for (final p in show) ...[
                        _PublicWorkPreview(post: p),
                        const SizedBox(height: AuraSpace.s10),
                      ],
                      const SizedBox(height: AuraSpace.s6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AuraSecondaryButton(
                          label: 'Explore more',
                          onPressed: () => context.go('/search'),
                          icon: Icons.explore_outlined,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const AuraLoadingState(message: 'Loading public work…'),
                error: (e, _) => AuraErrorState(
                  title: 'Could not load public work',
                  body: '$e',
                  action: AuraSecondaryButton(
                    label: 'Try again',
                    onPressed: () => ref.refresh(feedProvider),
                    icon: Icons.refresh_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicWorksHeader extends StatelessWidget {
  const _PublicWorksHeader(this.contextRef);

  final BuildContext contextRef;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuraBadge(
            label: 'Public platform',
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            'Build a public record of work that earns real consideration',
            style: AuraText.title.copyWith(fontSize: 30, height: 1.1),
          ),
          const SizedBox(height: AuraSpace.s12),
          const Text(
            'Aura is where creators publish writing and creations that can be discovered, evaluated, and taken seriously by others and institutions.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s14),
          Text(
            'No noise. Just structured, accountable work that holds weight over time.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s14),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: 'Join Aura',
                onPressed: () => contextRef.go('/register'),
                icon: Icons.arrow_forward_rounded,
              ),
              AuraSecondaryButton(
                label: 'Browse institutions',
                onPressed: () => contextRef.go('/institutions'),
                icon: Icons.apartment_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublicCalloutColumn extends StatelessWidget {
  const _PublicCalloutColumn({
    required this.onSearch,
    required this.onInstitutions,
    required this.onJoin,
  });

  final VoidCallback onSearch;
  final VoidCallback onInstitutions;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trust signals', style: AuraText.title.copyWith(fontSize: 17)),
              const SizedBox(height: AuraSpace.s8),
              const Text(
                'Discover public profiles, institutions, and announcements without losing the structure behind them.',
                style: AuraText.body,
              ),
              const SizedBox(height: AuraSpace.s12),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: [
                  AuraStatusChip(label: 'Verified identity', backgroundColor: AuraSurface.goodBg, textColor: AuraSurface.goodInk),
                  AuraStatusChip(label: 'Institution ready', backgroundColor: AuraSurface.infoBg, textColor: AuraSurface.infoInk),
                  AuraStatusChip(label: 'Public announcements', backgroundColor: AuraSurface.warnBg, textColor: AuraSurface.warnInk),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        AuraAdminTile(
          title: 'Search the platform',
          body: 'Find members, institutions, and public work with context attached.',
          icon: Icons.search_rounded,
          action: AuraSecondaryButton(label: 'Open search', onPressed: onSearch, icon: Icons.search_rounded),
        ),
        const SizedBox(height: AuraSpace.s12),
        AuraAdminTile(
          title: 'Institution discovery',
          body: 'See who is present, verified, and publishing on the platform.',
          icon: Icons.apartment_outlined,
          action: AuraSecondaryButton(label: 'Open institutions', onPressed: onInstitutions, icon: Icons.apartment_outlined),
        ),
        const SizedBox(height: AuraSpace.s12),
        AuraAdminTile(
          title: 'Create an account',
          body: 'Join the network and move into the full experience.',
          icon: Icons.person_add_alt_1_rounded,
          action: AuraPrimaryButton(label: 'Register', onPressed: onJoin, icon: Icons.arrow_forward_rounded),
        ),
      ],
    );
  }
}

class _PublicWorkPreview extends StatelessWidget {
  const _PublicWorkPreview({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    final authorMap = _asMap(a);
    final name = ((authorMap['displayName'] ?? a?.displayName ?? '') as String)
        .trim();
    final handle =
        ((authorMap['handle'] ?? a?.handle ?? '') as String).trim();

    final byline =
        handle.isEmpty ? name : '@$handle${name.isNotEmpty ? ' • $name' : ''}';

    final text = post.text.trim();
    final previewLength = MediaQuery.of(context).size.width < 600 ? 160 : 240;
    final preview = text.length <= previewLength
        ? text
        : '${text.substring(0, previewLength)}…';

    return AuraCard(
      onTap: () => context.push('/posts/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AuraSurface.divider),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: AuraTextBlock(
                  byline.isEmpty ? 'Work' : byline,
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AuraSurface.muted,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          AuraTextBlock(
            preview.isEmpty ? '—' : preview,
            style: AuraText.body.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
