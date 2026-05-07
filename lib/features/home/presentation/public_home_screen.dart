import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../app/shell/shell_shared.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../../institutions/live_rooms/global_live_discovery.dart';
import '../../institutions/live_rooms/live_now_card.dart';

class PublicHomeScreen extends ConsumerWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksAsync = ref.watch(globalPublicFeedProvider);
    final liveAsync = ref.watch(globalDiscoverableLiveProvider);

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeroSection(
            onJoin: () => context.go('/register'),
            onExplore: () => context.go('/search'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s28,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: _PublicFeedSection(
                  worksAsync: worksAsync,
                  liveAsync: liveAsync,
                  onExplore: () => context.go('/search'),
                ),
              ),
            ),
          ),
          const ShellFooter(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onJoin,
    required this.onExplore,
  });

  final VoidCallback onJoin;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AuraGradients.hero,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Stack(
        children: [
          // Subtle accent radial glow behind headline
          Positioned(
            top: -60,
            left: -80,
            child: Container(
              width: 480,
              height: 480,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1A5B6CFF), Colors.transparent],
                  radius: 0.65,
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s20,
                  60,
                  AuraSpace.s20,
                  56,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _HeroLeft(
                                  onJoin: onJoin,
                                  onExplore: onExplore,
                                ),
                              ),
                              const SizedBox(width: AuraSpace.s32),
                              const Expanded(
                                flex: 3,
                                child: _HeroPlatformCard(),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HeroLeft(onJoin: onJoin, onExplore: onExplore),
                              const SizedBox(height: AuraSpace.s24),
                              const _HeroPlatformCard(),
                            ],
                          );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLeft extends StatelessWidget {
  const _HeroLeft({required this.onJoin, required this.onExplore});

  final VoidCallback onJoin;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow label
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: AuraSpace.s6,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 11,
                color: AuraSurface.accentText,
              ),
              const SizedBox(width: AuraSpace.s6),
              Text(
                'Civic communication platform',
                style: AuraText.label.copyWith(color: AuraSurface.accentText),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s20),

        // Display headline
        const Text(
          'Work that earns\nreal consideration',
          style: AuraText.display,
        ),
        const SizedBox(height: AuraSpace.s16),

        // Sub-headline
        Text(
          'Publish writing, share creations, and build a public record that institutions and people take seriously — with no noise.',
          style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.6),
        ),
        const SizedBox(height: AuraSpace.s28),

        // CTAs
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            AuraPrimaryButton(
              label: 'Join Aura',
              onPressed: onJoin,
              icon: Icons.arrow_forward_rounded,
            ),
            _HeroOutlineButton(label: 'Explore work', onTap: onExplore),
          ],
        ),
        const SizedBox(height: AuraSpace.s20),

        // Trust pills
        const Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            _TrustPill(
              label: 'Verified identities',
              icon: Icons.verified_user_outlined,
            ),
            _TrustPill(
              label: 'Institution ready',
              icon: Icons.apartment_outlined,
            ),
            _TrustPill(label: 'No noise', icon: Icons.block_flipped),
          ],
        ),
      ],
    );
  }
}

class _HeroPlatformCard extends StatelessWidget {
  const _HeroPlatformCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
        boxShadow: AuraShadows.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform overview',
            style: AuraText.label.copyWith(
              color: AuraSurface.faint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          const _FeatureRow(
            icon: Icons.edit_note_rounded,
            title: 'Publish works',
            body: 'Writing, media, and long-form content with full provenance.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const Divider(color: AuraSurface.divider, height: 1),
          const SizedBox(height: AuraSpace.s12),
          const _FeatureRow(
            icon: Icons.apartment_rounded,
            title: 'Institutional trust',
            body: 'Verified institutions that signal professional context.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const Divider(color: AuraSurface.divider, height: 1),
          const SizedBox(height: AuraSpace.s12),
          const _FeatureRow(
            icon: Icons.mail_outline_rounded,
            title: 'Direct messages',
            body: 'Private, structured messaging for serious communication.',
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            icon,
            size: AuraIconSize.sm,
            color: AuraSurface.accentText,
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AuraSurface.ink,
                ),
              ),
              const SizedBox(height: AuraSpace.s2),
              Text(
                body,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AuraSurface.faint),
          const SizedBox(width: AuraSpace.s6),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroOutlineButton extends StatelessWidget {
  const _HeroOutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s20,
            vertical: AuraSpace.s12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.r14),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Text(
            label,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC FEED SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _PublicFeedSection extends StatelessWidget {
  const _PublicFeedSection({
    required this.worksAsync,
    required this.liveAsync,
    required this.onExplore,
  });

  final AsyncValue<FeedPage> worksAsync;
  final AsyncValue<List<LiveNowDiscoveryEntry>> liveAsync;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phase 2 Distribution — LIVE NOW band(s) above the works
        // section. Up to 3 entries (the upstream provider's cap).
        // Hidden silently when the loader is still working or no live
        // sessions are visible to this viewer.
        ...liveAsync.maybeWhen(
          data: (entries) => [
            for (final e in entries) ...[
              LiveNowCard(
                data: LiveNowCardData.fromDiscovery(
                  entry: e,
                  returnTo: '/',
                ),
              ),
              const SizedBox(height: AuraSpace.s10),
            ],
          ],
          orElse: () => const <Widget>[],
        ),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Public work', style: AuraText.headline),
                  SizedBox(height: AuraSpace.s4),
                  Text(
                    'Recent writing and creations from the network.',
                    style: AuraText.muted,
                  ),
                ],
              ),
            ),
            AuraGhostButton(
              label: 'Explore all',
              onPressed: onExplore,
              icon: Icons.explore_outlined,
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s20),
        worksAsync.when(
          data: (page) {
            if (page.items.isEmpty) {
              return const AuraEmptyState(
                title: 'No public work yet',
                body: 'When people publish, their work will appear here.',
                icon: Icons.public_outlined,
              );
            }
            return Column(
              children: [
                for (final item in page.items.take(6)) ...[
                  UnifiedFeedCard(item: item),
                  const SizedBox(height: AuraSpace.s10),
                ],
                const SizedBox(height: AuraSpace.s6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AuraSecondaryButton(
                    label: 'Explore more work',
                    onPressed: onExplore,
                    icon: Icons.explore_outlined,
                  ),
                ),
              ],
            );
          },
          loading: () =>
              const AuraLoadingState(message: 'Loading public work…'),
          error: (e, _) => const AuraErrorState(
            title: 'Could not load public work',
            body: 'Refresh the page or try again in a moment.',
          ),
        ),
      ],
    );
  }
}
