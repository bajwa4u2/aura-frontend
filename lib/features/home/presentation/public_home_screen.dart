import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/rail/rail_composition.dart';
import '../../../app/shell/shell_shared.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/responsive/adaptive_card_grid.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../institutions/live_rooms/global_live_discovery.dart';
import '../../institutions/live_rooms/live_now_card.dart';
import '../../public/data/public_spaces_repository.dart';
import '../../public/domain/space.dart';
import '../../public/widgets/discourse_card.dart';

/// Public-UX Phase 7 — homepage restructured around discourse: live
/// discussions, institution responses, spaces, and outcomes. Replaces
/// the prior publishing/work-platform framing.
///
/// Section order:
///   1. Hero (discourse positioning + auth-aware CTAs + live pulse)
///   2. Live Discourse rails (Active / Institution responded)
///   3. Discussion preview ("What's being discussed now")
///   4. How Aura works (4 steps)
///   5. Spaces (3 featured)
///   6. Participation band → /aura/participation
///   7. ShellFooter
class PublicHomeScreen extends ConsumerWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(globalPublicFeedProvider);
    final liveAsync = ref.watch(globalDiscoverableLiveProvider);
    final isAuthed = ref.watch(isAuthedProvider);

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeroSection(
            feedAsync: feedAsync,
            liveAsync: liveAsync,
            isAuthed: isAuthed,
          ),
          _LiveDiscourseSection(feedAsync: feedAsync, isAuthed: isAuthed),
          _DiscussionPreviewSection(feedAsync: feedAsync, isAuthed: isAuthed),
          const _HowItWorksSection(),
          const _SpacesSection(),
          const _PublicDiscoveryStrip(),
          const _ParticipationBand(),
          const ShellFooter(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSIFIER
// ─────────────────────────────────────────────────────────────────────────────

/// Splits the public feed into the rails the homepage cares about.
///
/// "Recently resolved" is intentionally NOT a rail — the global feed's
/// `replyPreview` payload doesn't carry an accountability-tag field, so
/// we can't reliably flag a thread as resolved from the homepage data.
/// Per the locked correction "do not show placeholder text that makes
/// the product feel empty", the rail is omitted rather than rendered
/// with weak data.
class _ClassifiedFeed {
  const _ClassifiedFeed({
    required this.active,
    required this.institutionResponded,
    required this.institutionResponseCount,
  });

  final List<FeedItem> active;
  final List<FeedItem> institutionResponded;

  /// Total institutional reply hits in the feed page (used by hero pulse).
  final int institutionResponseCount;

  bool get isEmpty => active.isEmpty && institutionResponded.isEmpty;

  static _ClassifiedFeed from(List<FeedItem> items) {
    final active = <FeedItem>[];
    final institution = <FeedItem>[];
    var instReplyHits = 0;
    for (final it in items) {
      final officialReplies = (it.replyPreview?.items ?? const [])
          .where((r) =>
              r.author.context?.type ==
              FeedIdentityContextType.officialInstitution)
          .toList(growable: false);
      if (officialReplies.isNotEmpty) {
        institution.add(it);
        instReplyHits += officialReplies.length;
        continue;
      }
      final replyCount = it.interaction.canViewReplyCount
          ? it.interaction.replyCount
          : 0;
      if (replyCount > 0 || (it.activity?.recentReply == true)) {
        active.add(it);
      }
    }
    return _ClassifiedFeed(
      active: active,
      institutionResponded: institution,
      institutionResponseCount: instReplyHits,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH-AWARE ROUTING HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _registerWithRedirect(String redirect) {
  final encoded = Uri.encodeComponent(redirect);
  return '/register?redirect=$encoded';
}

void _goJoinAura(BuildContext context, {required bool isAuthed}) {
  if (isAuthed) {
    context.go('/home');
  } else {
    context.go('/register');
  }
}

void _openThread(BuildContext context, FeedItem item) {
  context.push(item.targetRoute);
}

void _openThreadFocused(BuildContext context, FeedItem item, String focus) {
  final base = item.targetRoute;
  final sep = base.contains('?') ? '&' : '?';
  context.push('$base${sep}focus=$focus');
}

void _startDiscussion(
  BuildContext context,
  FeedItem item, {
  required bool isAuthed,
}) {
  if (isAuthed) {
    _openThread(context, item);
  } else {
    context.push(_registerWithRedirect(item.targetRoute));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.feedAsync,
    required this.liveAsync,
    required this.isAuthed,
  });

  final AsyncValue<FeedPage> feedAsync;
  final AsyncValue<List<LiveNowDiscoveryEntry>> liveAsync;
  final bool isAuthed;

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
              constraints: const BoxConstraints(maxWidth: kHeroWidth),
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
                    final left = _HeroLeft(isAuthed: isAuthed);
                    final right = _LiveDiscoursePulse(
                      feedAsync: feedAsync,
                      liveAsync: liveAsync,
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 5, child: left),
                          const SizedBox(width: AuraSpace.s32),
                          Expanded(flex: 3, child: right),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                        const SizedBox(height: AuraSpace.s24),
                        right,
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
  const _HeroLeft({required this.isAuthed});

  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                'Public discourse infrastructure',
                style: AuraText.label.copyWith(color: AuraSurface.accentText),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s20),
        const Text(
          'Where public discussions\nlead to real outcomes',
          style: AuraText.display,
        ),
        const SizedBox(height: AuraSpace.s16),
        Text(
          'People raise issues. Institutions respond. Outcomes are public.',
          style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.6),
        ),
        const SizedBox(height: AuraSpace.s28),
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            AuraPrimaryButton(
              label: isAuthed ? 'Open your feed' : 'Join Aura',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => _goJoinAura(context, isAuthed: isAuthed),
            ),
            _HeroOutlineButton(
              label: 'Explore discussions',
              onTap: () => context.go('/search'),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s12),
        // Institutional discovery — first-class entry point alongside the
        // discourse and join CTAs. Aura's brief is explicit that institutions
        // are the authority roots where public discourse happens, so a
        // visitor should be one click away from the institutional ecosystem.
        InkWell(
          onTap: () => context.go('/institutions'),
          borderRadius: BorderRadius.circular(AuraRadius.r10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s4,
              vertical: AuraSpace.s4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_outlined,
                  size: 14,
                  color: AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  'Browse the institutions on Aura',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AuraSurface.muted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s16),
        const Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            _TrustPill(
              label: 'Verified identities',
              icon: Icons.verified_user_outlined,
            ),
            _TrustPill(
              label: 'Institutions on record',
              icon: Icons.account_balance_outlined,
            ),
            _TrustPill(
              label: 'Outcomes are public',
              icon: Icons.task_alt_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _LiveDiscoursePulse extends StatelessWidget {
  const _LiveDiscoursePulse({
    required this.feedAsync,
    required this.liveAsync,
  });

  final AsyncValue<FeedPage> feedAsync;
  final AsyncValue<List<LiveNowDiscoveryEntry>> liveAsync;

  @override
  Widget build(BuildContext context) {
    final classified = feedAsync.maybeWhen(
      data: (p) => _ClassifiedFeed.from(p.items),
      orElse: () => const _ClassifiedFeed(
        active: [],
        institutionResponded: [],
        institutionResponseCount: 0,
      ),
    );
    final activeCount = classified.active.length +
        classified.institutionResponded.length;
    final liveEntries = liveAsync.maybeWhen(
      data: (l) => l,
      orElse: () => const <LiveNowDiscoveryEntry>[],
    );
    final liveCount = liveEntries.length;
    final firstLive = liveEntries.isNotEmpty ? liveEntries.first : null;

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
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              Text(
                'HAPPENING NOW',
                style: AuraText.label.copyWith(
                  color: AuraSurface.faint,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s14),
          _PulseStatRow(
            icon: Icons.forum_rounded,
            tint: AuraSurface.accent,
            label: 'active discussions',
            count: activeCount,
            loading: feedAsync.isLoading,
          ),
          const SizedBox(height: AuraSpace.s10),
          _PulseStatRow(
            icon: Icons.verified_rounded,
            tint: AuraSurface.accent,
            label: 'institution responses',
            count: classified.institutionResponseCount,
            loading: feedAsync.isLoading,
          ),
          const SizedBox(height: AuraSpace.s10),
          _PulseStatRow(
            icon: Icons.podcasts_rounded,
            tint: AuraSurface.accent,
            label: 'live now',
            count: liveCount,
            loading: liveAsync.isLoading,
          ),
          const SizedBox(height: AuraSpace.s12),
          // Honest context line — varies with the actual counts so the
          // closing line never lies. With three zero counts the box would
          // otherwise claim "Discussions are happening across spaces" while
          // the rail showed zeros next to it. Now the line reflects what
          // the numbers actually say.
          Text(
            (() {
              final any = activeCount > 0 ||
                  classified.institutionResponseCount > 0 ||
                  liveCount > 0;
              final all = activeCount > 0 &&
                  classified.institutionResponseCount > 0 &&
                  liveCount > 0;
              if (all) {
                return 'Discussions are happening across spaces right now';
              }
              if (any) {
                return 'Discourse is just starting to surface — stay close.';
              }
              return 'Quiet across the network right now. New discourse '
                  'shows up here as it lands.';
            })(),
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
          if (firstLive != null) ...[
            const SizedBox(height: AuraSpace.s14),
            const Divider(color: AuraSurface.divider, height: 1),
            const SizedBox(height: AuraSpace.s14),
            LiveNowCard(
              data: LiveNowCardData.fromDiscovery(
                entry: firstLive,
                returnTo: '/',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulseStatRow extends StatelessWidget {
  const _PulseStatRow({
    required this.icon,
    required this.tint,
    required this.label,
    required this.count,
    required this.loading,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final int count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final value = loading ? '—' : '$count';
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            border: Border.all(color: tint.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: AuraIconSize.sm, color: AuraSurface.accentText),
        ),
        const SizedBox(width: AuraSpace.s12),
        Text(
          value,
          style: AuraText.headline.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: AuraSpace.s8),
        Expanded(
          child: Text(
            label,
            style: AuraText.small.copyWith(color: AuraSurface.muted),
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
// SECTION 2 — LIVE DISCOURSE RAILS
// ─────────────────────────────────────────────────────────────────────────────

class _LiveDiscourseSection extends StatelessWidget {
  const _LiveDiscourseSection({
    required this.feedAsync,
    required this.isAuthed,
  });

  final AsyncValue<FeedPage> feedAsync;
  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    return feedAsync.maybeWhen(
      data: (page) {
        final classified = _ClassifiedFeed.from(page.items);
        // When the rails are empty we used to hide the section. That made
        // a quiet day on the network read as "the product is dead." Show
        // a launch-state placeholder instead: same heading, same scaffold
        // weight, with copy that frames the silence as intentional and
        // points to a concrete next action.
        if (classified.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              0,
              AuraSpace.s28,
              0,
              AuraSpace.s4,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kHeroWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeading(
                        title: 'Live discourse',
                        subtitle:
                            'When discussions move, they show up here',
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _LiveDiscoursePlaceholderCard(isAuthed: isAuthed),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            AuraSpace.s28,
            0,
            AuraSpace.s4,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kHeroWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeading(
                      title: 'Live discourse',
                      subtitle:
                          "What's happening across the network right now",
                    ),
                    const SizedBox(height: AuraSpace.s16),
                    if (classified.active.isNotEmpty) ...[
                      _DiscourseRail(
                        title: 'Active discussions',
                        icon: Icons.bolt_rounded,
                        count: classified.active.length,
                        items: classified.active.take(5).toList(),
                        kind: _RailKind.active,
                        ctaLabel: 'Join discussion',
                        onTap: (it) => _openThread(context, it),
                      ),
                      const SizedBox(height: AuraSpace.s16),
                    ],
                    if (classified.institutionResponded.isNotEmpty)
                      _DiscourseRail(
                        title: 'Institution responded',
                        icon: Icons.verified_rounded,
                        count: classified.institutionResponded.length,
                        items: classified.institutionResponded
                            .take(5)
                            .toList(),
                        kind: _RailKind.institutionResponded,
                        ctaLabel: 'View responses',
                        onTap: (it) => _openThreadFocused(
                          context,
                          it,
                          'first-official',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// Empty-state placeholder for the Live Discourse section. We show this
// instead of hiding the whole section when both rails would be empty —
// the public homepage needs to communicate that the discourse surface
// EXISTS and is something the visitor can join, even on a quiet day.
class _LiveDiscoursePlaceholderCard extends StatelessWidget {
  const _LiveDiscoursePlaceholderCard({required this.isAuthed});

  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.r16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.forum_outlined,
                size: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AuraSpace.s8),
              const Text('Quiet right now', style: AuraText.title),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'No active discussions in the last hour. New discourse '
            'shows up here as institutions respond and members start '
            'threads. Check back shortly, or start one yourself.',
            style: AuraText.body.copyWith(height: 1.5),
          ),
          const SizedBox(height: AuraSpace.s14),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              FilledButton(
                onPressed: () => context.go(isAuthed ? '/compose' : '/auth'),
                child: Text(isAuthed ? 'Start a discussion' : 'Join Aura'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/spaces'),
                child: const Text('Explore spaces'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscourseRail extends StatelessWidget {
  const _DiscourseRail({
    required this.title,
    required this.icon,
    required this.count,
    required this.items,
    required this.kind,
    required this.ctaLabel,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final int count;
  final List<FeedItem> items;
  final _RailKind kind;
  final String ctaLabel;
  final void Function(FeedItem) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: AuraIconSize.sm, color: AuraSurface.accentText),
            const SizedBox(width: AuraSpace.s8),
            Text(
              title,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: AuraSpace.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AuraSurface.accentSoft,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(
                  color: AuraSurface.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$count',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s10),
        // Discourse rails — operational cards, not chips. On tablet/desktop
        // they wrap into a grid (2–4 columns by available width). On narrow
        // viewports they fall back to a pointer-aware horizontal rail with
        // mouse-wheel + arrow keys + chevron affordances, so no card is
        // unreachable on any pointing input. cardHeight is REQUIRED so the
        // narrow rail doesn't throw "Vertical viewport given unbounded
        // height" — a previous build that wrapped each card in SizedBox
        // height 196 but forgot to bound the rail itself caused the
        // entire feed below to fail rendering.
        AdaptiveCardGrid(
          cards: [
            for (final item in items)
              _RailCard(
                item: item,
                kind: kind,
                ctaLabel: ctaLabel,
                onTap: () => onTap(item),
              ),
          ],
          cardWidth: 320,
          cardHeight: 196,
          gap: AuraSpace.s10,
          minCardsPerRow: 2,
          maxCardsPerRow: 4,
        ),
      ],
    );
  }
}

/// Phase-7 polish — differentiates rail cards visually so a scanning
/// eye instantly tells "Active" from "Institution responded". Both
/// pills stay inside the existing accent token family so we don't
/// introduce new colors.
enum _RailKind { active, institutionResponded }

class _RailCard extends StatelessWidget {
  const _RailCard({
    required this.item,
    required this.kind,
    required this.ctaLabel,
    required this.onTap,
  });

  final FeedItem item;
  final _RailKind kind;
  final String ctaLabel;
  final VoidCallback onTap;

  String get _headline {
    final t = item.title?.trim() ?? '';
    if (t.isNotEmpty) return t;
    final body = item.body.trim();
    if (body.length <= 80) return body;
    return '${body.substring(0, 80)}…';
  }

  @override
  Widget build(BuildContext context) {
    final replyCount = item.interaction.canViewReplyCount
        ? item.interaction.replyCount
        : 0;
    final spaceName = item.publicSpaceName?.trim() ?? '';
    final authorName = item.author.name.trim();
    final officialReplies = (item.replyPreview?.items ?? const [])
        .where((r) =>
            r.author.context?.type ==
            FeedIdentityContextType.officialInstitution)
        .toList(growable: false);
    // Width comes from the parent (AdaptiveCardGrid sizes the cell in
    // both rail and grid modes); the previous hard-coded 320 fought the
    // grid wrap on wide viewports.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.lg),
            border: Border.all(color: AuraSurface.divider),
            boxShadow: AuraShadows.panel,
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RailPill(kind: kind),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  _headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AuraSpace.s6),
                Text(
                  [
                    if (authorName.isNotEmpty) authorName,
                    if (spaceName.isNotEmpty) 'in $spaceName',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: AuraSurface.faint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                      style: AuraText.micro
                          .copyWith(color: AuraSurface.muted),
                    ),
                    if (officialReplies.isNotEmpty) ...[
                      const SizedBox(width: AuraSpace.s8),
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AuraSurface.accentText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${officialReplies.length} institution${officialReplies.length == 1 ? '' : 's'}',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.accentText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AuraSpace.s8),
                Row(
                  children: [
                    Text(
                      ctaLabel,
                      style: AuraText.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AuraSurface.accentText,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AuraSurface.accentText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
  }
}

/// Pulse pill on the rail card — leading marker that distinguishes
/// active discussions from institution-responded threads at a glance.
/// Both variants use existing accent tokens; the institutional variant
/// gets a stronger fill + border so it reads as authoritative without
/// introducing a new color.
class _RailPill extends StatelessWidget {
  const _RailPill({required this.kind});

  final _RailKind kind;

  @override
  Widget build(BuildContext context) {
    final isInstitutional = kind == _RailKind.institutionResponded;
    final label =
        isInstitutional ? 'Institution involved' : 'Active discussion';
    final icon = isInstitutional ? Icons.verified_rounded : Icons.bolt_rounded;
    final bg = isInstitutional
        ? AuraSurface.accent.withValues(alpha: 0.18)
        : AuraSurface.accentSoft;
    final border = isInstitutional
        ? AuraSurface.accent.withValues(alpha: 0.55)
        : AuraSurface.accent.withValues(alpha: 0.3);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AuraSurface.accentText),
          const SizedBox(width: 4),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.accentText,
              fontWeight: isInstitutional ? FontWeight.w900 : FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 3 — DISCUSSION PREVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _DiscussionPreviewSection extends StatelessWidget {
  const _DiscussionPreviewSection({
    required this.feedAsync,
    required this.isAuthed,
  });

  final AsyncValue<FeedPage> feedAsync;
  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s28,
        AuraSpace.s16,
        AuraSpace.s8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kHeroWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _SectionHeading(
                      title: "What's being discussed now",
                      subtitle: 'Live conversations across spaces',
                    ),
                  ),
                  AuraGhostButton(
                    label: 'See all discussions',
                    icon: Icons.explore_outlined,
                    onPressed: () => context.go('/search'),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s16),
              feedAsync.when(
                data: (page) {
                  if (page.items.isEmpty) {
                    return const AuraEmptyState(
                      title: 'No public discussions yet',
                      body:
                          'When people raise issues and institutions respond, those discussions appear here.',
                      icon: Icons.forum_outlined,
                    );
                  }
                  final items = page.items.take(6).toList(growable: false);
                  return Column(
                    children: [
                      for (final item in items) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DiscourseCard(
                              item: item,
                              showInteractionBar: isAuthed,
                              // Phase-7 polish — homepage owns its own
                              // footer strip below; suppress the card's
                              // built-in CTA so we don't stack two.
                              showEntryHookCta: false,
                            ),
                            _DiscourseRailFooter(
                              item: item,
                              isAuthed: isAuthed,
                            ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s10),
                      ],
                    ],
                  );
                },
                loading: () =>
                    const AuraLoadingState(message: 'Loading discussions…'),
                error: (e, _) => const AuraErrorState(
                  title: 'Could not load discussions',
                  body: 'Refresh the page or try again in a moment.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-card footer strip — single-line participation CTA matched to the
/// discussion's state. Auth-aware: signed-out "Start the discussion"
/// routes through `/register?redirect=…`; everything else lands on the
/// thread directly (where the existing compose flow handles auth).
class _DiscourseRailFooter extends StatelessWidget {
  const _DiscourseRailFooter({
    required this.item,
    required this.isAuthed,
  });

  final FeedItem item;
  final bool isAuthed;

  bool get _hasInstitutionalReply =>
      (item.replyPreview?.items ?? const []).any((r) =>
          r.author.context?.type ==
          FeedIdentityContextType.officialInstitution);

  int get _replyCount => item.interaction.canViewReplyCount
      ? item.interaction.replyCount
      : 0;

  @override
  Widget build(BuildContext context) {
    final String label;
    final String cta;
    final VoidCallback onTap;
    final IconData icon;
    if (_hasInstitutionalReply) {
      label = 'Institution responded';
      cta = 'View responses';
      icon = Icons.verified_rounded;
      onTap = () => _openThreadFocused(context, item, 'first-official');
    } else if (_replyCount == 0) {
      label = 'No responses yet';
      cta = 'Start the discussion';
      icon = Icons.bolt_outlined;
      onTap = () => _startDiscussion(context, item, isAuthed: isAuthed);
    } else {
      label = '$_replyCount people discussing';
      cta = 'Join discussion';
      icon = Icons.forum_outlined;
      onTap = () => _openThread(context, item);
    }
    // Phase-7 polish — tinted background + top divider so the strip
    // reads as a separate actionable layer beneath the card body, not
    // as an extension of the content. Fixed height keeps every state
    // visually identical so the eye lands in the same spot every row.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AuraRadius.lg),
          bottomRight: Radius.circular(AuraRadius.lg),
        ),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
          ),
          decoration: const BoxDecoration(
            color: AuraSurface.subtle,
            border: Border(top: BorderSide(color: AuraSurface.divider)),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(AuraRadius.lg),
              bottomRight: Radius.circular(AuraRadius.lg),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AuraSurface.muted),
              const SizedBox(width: AuraSpace.s6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              const Spacer(),
              Text(
                cta,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: AuraText.small.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AuraSurface.accentText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 4 — HOW AURA WORKS
// ─────────────────────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _HowItWorksStep(
        index: 1,
        icon: Icons.forum_outlined,
        label: 'People raise issues',
      ),
      _HowItWorksStep(
        index: 2,
        icon: Icons.reply_rounded,
        label: 'Others respond',
      ),
      _HowItWorksStep(
        index: 3,
        icon: Icons.account_balance_outlined,
        label: 'Institutions act',
      ),
      _HowItWorksStep(
        index: 4,
        icon: Icons.task_alt_rounded,
        label: 'Outcomes are public',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s32,
        AuraSpace.s16,
        AuraSpace.s8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kHeroWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                title: 'How Aura works',
                subtitle: 'Four steps. That is the whole loop.',
              ),
              const SizedBox(height: AuraSpace.s16),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 720;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          Expanded(child: steps[i]),
                          if (i != steps.length - 1)
                            const SizedBox(width: AuraSpace.s12),
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (final s in steps) ...[
                        s,
                        const SizedBox(height: AuraSpace.s10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({
    required this.index,
    required this.icon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AuraSurface.accentSoft,
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              border: Border.all(
                color: AuraSurface.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, color: AuraSurface.accentText, size: 20),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP $index',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 5 — SPACES
// ─────────────────────────────────────────────────────────────────────────────

class _SpacesSection extends ConsumerWidget {
  const _SpacesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesAsync = ref.watch(publicSpacesListProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s32,
        AuraSpace.s16,
        AuraSpace.s8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kHeroWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _SectionHeading(
                      title: 'Where discourse lives',
                      subtitle: 'Topic homes for serious discussion',
                    ),
                  ),
                  AuraGhostButton(
                    label: 'Browse all spaces',
                    icon: Icons.grid_view_rounded,
                    onPressed: () => context.go('/spaces'),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s16),
              spacesAsync.when(
                data: (spaces) {
                  if (spaces.isEmpty) return const SizedBox.shrink();
                  final featured = spaces.take(3).toList(growable: false);
                  return LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 720;
                      if (wide) {
                        return Row(
                          children: [
                            for (var i = 0; i < featured.length; i++) ...[
                              Expanded(
                                child: _SpaceTile(space: featured[i]),
                              ),
                              if (i != featured.length - 1)
                                const SizedBox(width: AuraSpace.s12),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: [
                          for (final s in featured) ...[
                            _SpaceTile(space: s),
                            const SizedBox(height: AuraSpace.s10),
                          ],
                        ],
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
                  child: AuraLoadingState(message: 'Loading spaces…'),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaceTile extends ConsumerWidget {
  const _SpaceTile({required this.space});

  final PubSpace space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(publicSpaceSummaryProvider(space.slug));
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    color: AuraSurface.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  space.icon,
                  size: 18,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text(
                  space.name,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            space.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          summaryAsync.when(
            data: (s) => Text(
              '${s.activeDiscussionCount} active · ${s.institutionCount} institutions',
              style: AuraText.micro.copyWith(
                color: AuraSurface.faint,
                fontWeight: FontWeight.w600,
              ),
            ),
            loading: () => Text(
              'Active',
              style: AuraText.micro.copyWith(color: AuraSurface.faint),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AuraSpace.s4),
          // Phase-7 polish — single muted line so each space tile reads
          // as alive, not as a static directory entry.
          Text(
            'Discussions happening now',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraSecondaryButton(
            label: 'Enter space',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.push('/spaces/${space.slug}'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 6 — PARTICIPATION BAND
// ─────────────────────────────────────────────────────────────────────────────

class _ParticipationBand extends StatelessWidget {
  const _ParticipationBand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s32,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kHeroWidth),
          child: Container(
            padding: const EdgeInsets.all(AuraSpace.s20),
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.lg),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 720;
                final body = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How participation works',
                      style: AuraText.headline.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    Text.rich(
                      TextSpan(
                        style: AuraText.body.copyWith(
                          color: AuraSurface.muted,
                          height: 1.55,
                        ),
                        children: [
                          TextSpan(
                            text:
                                'Institutions respond and act publicly here.',
                            style: AuraText.body.copyWith(
                              color: AuraSurface.ink,
                              fontWeight: FontWeight.w800,
                              height: 1.55,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          const TextSpan(
                            text:
                                'Paid actions — priority responses and hosted sessions — are always labeled. Identities are verified.',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final cta = AuraSecondaryButton(
                  label: 'How participation works',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => context.push('/aura/participation'),
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: body),
                      const SizedBox(width: AuraSpace.s24),
                      cta,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    body,
                    const SizedBox(height: AuraSpace.s16),
                    cta,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED — SECTION HEADING
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.headline),
        const SizedBox(height: AuraSpace.s4),
        Text(subtitle, style: AuraText.muted),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC DISCOVERY STRIP
// ─────────────────────────────────────────────────────────────────────────────

/// Public-shell ecosystem-depth section. Surfaces the same provider-
/// backed rail modules used in the authenticated rails (verified
/// institutions, live now, pinned announcements, governance) inside the
/// public landing's single-column ListView. At desktop they sit as a
/// 3-up row; at tablet/mobile they stack as a column. Each module self-
/// hides when its provider has nothing — so an empty platform shows
/// only the static governance note instead of a wall of blanks.
///
/// This intentionally does not touch `PublicShell` — the shell remains
/// a thin header + body. Ecosystem depth lives at the route level.
class _PublicDiscoveryStrip extends StatelessWidget {
  const _PublicDiscoveryStrip();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= kDesktopBreak;
        final hPad = isDesktop ? AuraSpace.s24 : AuraSpace.s16;
        return Container(
          padding: EdgeInsets.fromLTRB(
              hPad, AuraSpace.s32, hPad, AuraSpace.s32),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AuraSurface.divider),
              bottom: BorderSide(color: AuraSurface.divider),
            ),
            color: AuraSurface.elevated,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kHeroWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ecosystem at a glance',
                    style: AuraText.headline.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    'Verified institutions, what is live now, '
                    'and how Aura works on the public record.',
                    style: AuraText.body.copyWith(color: AuraSurface.muted),
                  ),
                  const SizedBox(height: AuraSpace.s20),
                  // Public discovery columns come from the shared
                  // composition engine — same modules the member,
                  // institution, and admin rails consume, arranged for
                  // the public-home single-page landing.
                  if (isDesktop)
                    _PublicDiscoveryRow(
                      columns: publicDiscoveryColumns(),
                    )
                  else
                    _PublicDiscoveryStack(
                      modules: publicDiscoveryColumns().stacked,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Three-column desktop layout for the public discovery strip. Maps
/// `PublicDiscoveryColumns.civicSignal | ecosystem | continuity` to a
/// side-by-side Row. Each column is its own `Expanded(Column)`, so a
/// column with no populated modules simply renders zero height — no
/// dead decorative boxes.
class _PublicDiscoveryRow extends StatelessWidget {
  const _PublicDiscoveryRow({required this.columns});

  final PublicDiscoveryColumns columns;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _DiscoveryColumn(modules: columns.civicSignal)),
        const SizedBox(width: AuraSpace.s16),
        Expanded(child: _DiscoveryColumn(modules: columns.ecosystem)),
        const SizedBox(width: AuraSpace.s16),
        Expanded(child: _DiscoveryColumn(modules: columns.continuity)),
      ],
    );
  }
}

/// Single-column stack used at tablet/mobile widths. Receives the flat
/// `stacked` ordering from `PublicDiscoveryColumns.stacked` so the
/// civic-signal modules still lead before ecosystem and continuity.
class _PublicDiscoveryStack extends StatelessWidget {
  const _PublicDiscoveryStack({required this.modules});

  final List<Widget> modules;

  @override
  Widget build(BuildContext context) {
    return _DiscoveryColumn(modules: modules);
  }
}

class _DiscoveryColumn extends StatelessWidget {
  const _DiscoveryColumn({required this.modules});

  final List<Widget> modules;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < modules.length; i++) ...[
          modules[i],
          if (i < modules.length - 1) const SizedBox(height: AuraSpace.s12),
        ],
      ],
    );
  }
}
