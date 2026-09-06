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
import '../../../core/ui/surface/surface_composition.dart';
import '../../../core/ui/aura_window.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../institutions/live_rooms/global_live_discovery.dart';
import '../../institutions/live_rooms/live_now_card.dart';
import '../../discourse_intelligence/widgets/civic_memory_continuity_cue.dart';
import '../../public/data/public_spaces_repository.dart';
import '../../public/domain/space.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
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
      // THE SECTIONS ARE THE COMPOSITION; THE PAGE MUST NOT RE-CROP THEM.
      //
      // Home was inheriting `AuraScaffold`'s default page band, so the whole
      // landing was a 1320 px column inside a 2000 px window. Every section
      // already centres its own content at `kHeroWidth`, so the band bought
      // nothing — but the sections that paint a BACKGROUND (the hero
      // gradient, the ecosystem strip's rules) were cropped to that column
      // and read as cards floating on the page rather than as bands of it.
      // On the maximised client the hero was a visible 1311 px rectangle
      // with dark page either side.
      //
      // Window composition is resolved once. Here that resolution belongs to
      // the sections: full-bleed surface, content centred inside it.
      maxWidth: AuraScaffold.childDecidesWidth,
      // ONE ARC: ARRIVAL → UNDERSTANDING → ENCOUNTER → PARTICIPATION → CLOSING.
      //
      // What this replaces was nine sections in the order they were built:
      //
      //   hero → live-discourse rail → the same discussions again as full
      //   cards → continuity cue → how it works → spaces → ecosystem →
      //   a bordered promo restating Aura → footer
      //
      // Two defects were structural rather than visual, and no amount of
      // restyling would have reached either.
      //
      //   * THE ENCOUNTER HAPPENED TWICE. `_LiveDiscourseSection` and
      //     `_DiscussionPreviewSection` both read `globalPublicFeedProvider`:
      //     the first as summary rail cards under "Live discourse", the
      //     second as the real posts under "What's being discussed now". A
      //     visitor met the same three discussions twice in a row, under two
      //     headings that mean the same thing. The real posts are the
      //     encounter; the rail was a preview of what came next. Retired.
      //     Nothing is lost — the institution-responded signal the rail
      //     carried is already rendered inside each card's footer strip.
      //
      //   * UNDERSTANDING ARRIVED AFTER ENCOUNTER. "How Aura works" is four
      //     short steps and it explains what the discussions below it are.
      //     It sat five sections down. It now bridges the hero and the
      //     discourse, which is the job it was written for.
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ARRIVAL
          _HeroSection(
            feedAsync: feedAsync,
            liveAsync: liveAsync,
            isAuthed: isAuthed,
          ),
          // UNDERSTANDING
          const _HowItWorksSection(),
          // ENCOUNTER
          _DiscussionPreviewSection(feedAsync: feedAsync, isAuthed: isAuthed),
          const SizedBox(height: AuraSpace.s14),
          // The cue paints no background of its own and does not centre
          // itself, so it takes the page's reading band explicitly rather
          // than stretching to the window.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kHeroWidth),
              child: const CivicMemoryContinuityCue(),
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          // PARTICIPATION
          const _SpacesSection(),
          const _PublicDiscoveryStrip(),
          // CLOSING
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
          .where(
            (r) =>
                r.author.context?.type ==
                FeedIdentityContextType.officialInstitution,
          )
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
                // Vertical rhythm by window, not a fixed 60/56 tuned for a
                // phone hero. On a desktop window that padding pushed the
                // fold past everything worth seeing.
                padding: EdgeInsets.fromLTRB(
                  AuraSpace.s20,
                  AuraWindow.of(context).windowClass.canHoldSelection ? 32 : 60,
                  AuraSpace.s20,
                  AuraWindow.of(context).windowClass.canHoldSelection ? 28 : 56,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    final left = _HeroLeft(isAuthed: isAuthed);
                    // The activity module is optional. When the network has
                    // nothing current to show, the hero is the whole band
                    // rather than a headline column with a hole beside it.
                    if (!_LiveDiscoursePulse.hasCurrentActivity(
                      feedAsync,
                      liveAsync,
                    )) {
                      return left;
                    }
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
                Icons.forum_rounded,
                size: 11,
                color: AuraSurface.accentText,
              ),
              const SizedBox(width: AuraSpace.s6),
              // A `mainAxisSize: min` Row asks its Text for the width the
              // sentence WANTS, so at any surface narrower than that the pill
              // overflows — 76px at 800 wide, still 1px at 1600. Constraining
              // the text lets the pill shrink instead of spilling.
              Flexible(
                child: Text(
                  'Public communication with accountability',
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.label.copyWith(color: AuraSurface.accentText),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s20),
        // Public-first causal doctrine — people and the communication they
        // already struggle with are the originating force; institutions
        // enter as accountable participants. The previous hero led with an
        // institutions-first, verification-as-premise headline — the
        // prohibited acquisition framing (see the public-first gate).
        // A HEADLINE SIZED FOR THE WINDOW IT IS IN.
        //
        // `AuraText.display` is a phone hero size. Unchanged on a 2000 px
        // desktop window it filled the viewport on its own, so the installed
        // client opened on one enormous sentence and everything real — the
        // live discourse panel beside it, the sections below — was a scroll
        // away. That is what made the signed-out client read as a marketing
        // website running inside an EXE.
        //
        // The hard line break goes with it: it was placed for a narrow
        // measure and, at desktop width, broke the sentence in the wrong
        // place while leaving the line half empty.
        Builder(
          builder: (context) {
            final desktop = AuraWindow.of(context).windowClass.canHoldSelection;
            return Text(
              desktop
                  ? 'Public conversation that keeps its context.'
                  : 'Public conversation that\nkeeps its context.',
              // 46 was WRONG and I put it there. `AuraText.display` is 40 --
              // I assumed it was an oversized phone-hero style without
              // reading it, so the "desktop correction" made the headline
              // BIGGER than the thing it was correcting. Looking at the
              // running client is what caught it.
              //
              // The size was never the problem. What made the first view read
              // as a marketing page was the hard line break and a header and
              // hero band that floated in the middle of the window; both are
              // addressed where they actually live.
              style: AuraText.display,
            );
          },
        ),
        const SizedBox(height: AuraSpace.s16),
        // ONE THOUGHT, NOT SIX CLAIMS.
        //
        // This paragraph ran 55 words and made five separate claims, three of
        // them about institutions — it named governments, universities,
        // agencies and associations before a visitor had been told what the
        // product does for a person. That reverses the causal order Aura is
        // built on: public communication is the originating force and
        // institutional accountability is what follows from institutions
        // participating in it, not the reason to be here.
        //
        // What remains is the part only Aura claims: you speak as yourself,
        // and what was said stays legible afterwards. Institutions arrive
        // three lines later, as step three of a loop and as a place to
        // browse — participants, not premise.
        Text(
          'Raise what matters in the open, with people who answer under their '
          'real name. Conversations keep their history, so what was said and '
          'what was promised are still there later.',
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
            // C3 froze Discover as the consolidated discovery intention and
            // Search as a facet of it. "Explore discussions" was routing to
            // the search box — a label promising discussions and a
            // destination offering an empty field.
            _HeroOutlineButton(
              label: 'Explore discussions',
              onTap: () => context.push('/discover'),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s12),
        // Institutional discovery — a legitimate first-class capability
        // (public-first doctrine: institution discovery remains real; it is
        // simply not the originating proposition of the entry surface).
        InkWell(
          onTap: () => context.push('/institutions'),
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
        // THE TRUST CHIPS ARE GONE, AND THEY WERE NOT A LOSS.
        //
        // "Accountable identities · Institutions on record · Outcomes are
        // public" are steps 1, 3 and 4 of "How Aura works", which now sits
        // directly beneath the hero. The first view was carrying an eyebrow,
        // a headline, a paragraph, two buttons, a text link, an activity
        // panel AND three badges — seven mechanisms all explaining the same
        // product. Saying a thing twice in one viewport does not make it
        // twice as true; it makes the surface read as though it does not
        // trust the sentence above.
      ],
    );
  }
}

/// HAPPENING NOW — SHOWN ONLY WHEN SOMETHING IS.
///
/// This panel used to render unconditionally, three rows deep, beside the
/// headline. On the live network that meant a signed-out visitor's first
/// view of Aura was:
///
///     3 active discussions
///     0 institution responses
///     0 live now
///     "Discourse is just starting to surface — stay close."
///
/// Every number true, and the composition still wrong: a scoreboard whose
/// dominant value is zero makes the product's immaturity the co-star of its
/// own hero, and the line underneath asked a stranger to be patient with a
/// product they had known for four seconds.
///
/// The correction is not to invent numbers or soften the words. It is to let
/// the module earn its prominence:
///
///   * HAPPENING NOW MEANS NOW. Live sessions and institutional responses are
///     current events. A handful of discussions with a reply each is the
///     archive, and the encounter section renders it properly a screen below
///     — so the panel is not the only way to learn it exists.
///   * ZERO ROWS ARE NOT SHOWN. A count of nothing is not a signal, and
///     three of them in a bordered card is a scoreboard of absence.
///   * NO REASSURANCE LINE. Aura presents what exists; it does not ask to be
///     graded on a curve.
///
/// When nothing qualifies the module is absent and the hero takes the whole
/// width — which is the honest use of the space, not a gap where a widget
/// used to be.
class _LiveDiscoursePulse extends StatelessWidget {
  const _LiveDiscoursePulse({required this.feedAsync, required this.liveAsync});

  final AsyncValue<FeedPage> feedAsync;
  final AsyncValue<List<LiveNowDiscoveryEntry>> liveAsync;

  /// Whether the network has something current worth a module in the hero.
  ///
  /// Deliberately NOT "any count above zero". Asked by `_HeroSection` before
  /// it chooses its layout, so the decision is made once and the panel and
  /// the space it would occupy can never disagree.
  static bool hasCurrentActivity(
    AsyncValue<FeedPage> feedAsync,
    AsyncValue<List<LiveNowDiscoveryEntry>> liveAsync,
  ) {
    final live = liveAsync.maybeWhen(data: (l) => l.length, orElse: () => 0);
    if (live > 0) return true;
    final responses = feedAsync.maybeWhen(
      data: (p) => _ClassifiedFeed.from(p.items).institutionResponseCount,
      orElse: () => 0,
    );
    return responses > 0;
  }

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
    final activeCount =
        classified.active.length + classified.institutionResponded.length;
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
          // Only what is actually happening. A row per non-zero signal, in
          // the same order as before so the panel is recognisable when it
          // does appear.
          for (final row in <Widget>[
            if (liveCount > 0)
              _PulseStatRow(
                icon: Icons.podcasts_rounded,
                tint: AuraSurface.accent,
                label: 'live now',
                count: liveCount,
                loading: false,
              ),
            if (classified.institutionResponseCount > 0)
              _PulseStatRow(
                icon: Icons.account_balance_rounded,
                tint: AuraSurface.accent,
                label: 'institution responses',
                count: classified.institutionResponseCount,
                loading: false,
              ),
            if (activeCount > 0)
              _PulseStatRow(
                icon: Icons.forum_rounded,
                tint: AuraSurface.accent,
                label: 'active discussions',
                count: activeCount,
                loading: false,
              ),
          ]) ...[row, const SizedBox(height: AuraSpace.s10)],
          // NO CLOSING LINE.
          //
          // Every version of it was launch-stage reassurance: "stay close",
          // "just starting to surface", "shows up here as it lands". The
          // counts above are the statement. A number that is present does
          // not need to be apologised for, and a number that is absent is
          // no longer shown.
          if (firstLive != null) ...[
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
          child: Icon(
            icon,
            size: AuraIconSize.sm,
            color: AuraSurface.accentText,
          ),
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
// SECTION 3 — DISCUSSION PREVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _DiscussionPreviewSection extends ConsumerWidget {
  const _DiscussionPreviewSection({
    required this.feedAsync,
    required this.isAuthed,
  });

  final AsyncValue<FeedPage> feedAsync;
  final bool isAuthed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s28,
        AuraSpace.s16,
        AuraSpace.s8,
      ),
      // THE DISCUSSIONS ARE READ, SO THE WHOLE SECTION IS A READING COLUMN.
      //
      // Signed in, this exact card lives in a `discourseFeed` surface: the
      // `feed` measure with a context rail beside it, so its real column is
      // roughly 1320 minus the rail. Public Home has no rail, so the same
      // card was handed the entire page band and a paragraph ran about 140
      // characters to the line. One object shown at two very different
      // measures in two realms is the clearest way to make a product feel
      // like two products.
      //
      // The same arithmetic gives the card the same width it has signed in.
      // The HEADING travels with it rather than staying on the wider band:
      // held out to `kHeroWidth` it ran past the right edge of its own
      // cards, and a heading wider than what it heads reads as a section
      // that lost its contents.
      child: Center(
        child: LayoutBuilder(
          builder: (context, outer) {
            final rail = AuraContextRail.widthFor(
              MediaQuery.sizeOf(context).width,
            );
            final column = (kHeroWidth - rail - AuraSpace.s16).clamp(
              kReadWidth,
              kHeroWidth,
            );
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: column),
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
                        onPressed: () => context.push('/discover'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  _buildDiscussions(context, ref),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDiscussions(BuildContext context, WidgetRef ref) {
    return feedAsync.when(
      data: (page) {
        if (page.items.isEmpty) {
          return const AuraProductState(
            state: ProductState.empty,
            headline: 'No public discussions yet',
            detail:
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
                  _DiscourseRailFooter(item: item, isAuthed: isAuthed),
                ],
              ),
              const SizedBox(height: AuraSpace.s10),
            ],
          ],
        );
      },
      loading: () => const AuraProductState(
        state: ProductState.loading,
        headline: 'Loading discussions…',
      ),
      error: (e, _) => AuraProductState(
        state: ProductState.retryableError,
        headline: 'Could not load discussions',
        onRecover: () => ref.invalidate(globalPublicFeedProvider),
      ),
    );
  }
}

/// Per-card footer strip — single-line participation CTA matched to the
/// discussion's state. Auth-aware: signed-out "Start the discussion"
/// routes through `/register?redirect=…`; everything else lands on the
/// thread directly (where the existing compose flow handles auth).
class _DiscourseRailFooter extends StatelessWidget {
  const _DiscourseRailFooter({required this.item, required this.isAuthed});

  final FeedItem item;
  final bool isAuthed;

  bool get _hasInstitutionalReply => (item.replyPreview?.items ?? const []).any(
    (r) =>
        r.author.context?.type == FeedIdentityContextType.officialInstitution,
  );

  int get _replyCount =>
      item.interaction.canViewReplyCount ? item.interaction.replyCount : 0;

  @override
  Widget build(BuildContext context) {
    final String label;
    final String cta;
    final VoidCallback onTap;
    final IconData icon;
    if (_hasInstitutionalReply) {
      label = 'Institution responded';
      cta = 'View responses';
      icon = Icons.account_balance_rounded;
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
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14),
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
              const SizedBox(height: AuraSpace.s14),
              // PARTICIPATION, COMPOSED QUIETLY.
              //
              // This replaces `_ParticipationBand`: a full-width bordered
              // panel, headline weight, that sat between the last real
              // content and the footer and used that position to restate the
              // product ("Institutions respond and act publicly here"),
              // explain paid actions, and offer a button — three marketing
              // moves in the place a page should be ending. It made the last
              // thing a visitor read about Aura the commercial mechanics.
              //
              // Commercial transparency is not negotiable and has not been
              // reduced: the sentence still says paid actions exist and are
              // labelled, and `/aura/participation` still carries the full
              // account. What changed is that it now sits where the loop is
              // explained — one line, at the end of the explanation it
              // belongs to — instead of becoming Home's closing identity.
              _QuietContinuation(
                text:
                    'Some institutional actions are paid, such as priority '
                    'responses and hosted sessions. Those are always '
                    'labelled.',
                label: 'How participation works',
                onTap: () => context.push('/aura/participation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A sentence and a way onward. Used where a section has a legitimate
/// continuation that does not deserve a panel of its own.
class _QuietContinuation extends StatelessWidget {
  const _QuietContinuation({
    required this.text,
    required this.label,
    required this.onTap,
  });

  final String text;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
            height: 1.55,
          ),
        ),
        const SizedBox(height: AuraSpace.s6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w700,
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
      ],
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
                    onPressed: () => context.push('/spaces'),
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
                              Expanded(child: _SpaceTile(space: featured[i])),
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
                  child: AuraProductState(
                    state: ProductState.loading,
                    headline: 'Loading spaces…',
                  ),
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
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
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
            hPad,
            AuraSpace.s32,
            hPad,
            AuraSpace.s32,
          ),
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
                  // The trailing clause used to be "and how Aura works on
                  // the public record" — a third telling of the thing the
                  // hero and "How Aura works" have already said. This
                  // section's job is to name what is actually here.
                  Text(
                    'Verified institutions and what is live now.',
                    style: AuraText.body.copyWith(color: AuraSurface.muted),
                  ),
                  const SizedBox(height: AuraSpace.s20),
                  // Public discovery columns come from the shared
                  // composition engine — same modules the member,
                  // institution, and admin rails consume, arranged for
                  // the public-home single-page landing.
                  if (isDesktop)
                    _PublicDiscoveryRow(columns: publicDiscoveryColumns())
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
    // AN EMPTY COLUMN TAKES NO SPACE.
    //
    // This was three unconditional `Expanded`s. Each column self-hides when
    // its providers have nothing, so on the live network, where only the
    // continuity column was populated, the row rendered two empty thirds and
    // pushed three small cards into the far right of a 2000 px window with
    // the other two thirds blank. Nothing was broken by any single widget;
    // the row simply kept paying for panes that had declined to exist.
    //
    // The modules already earn their place. The COLUMNS have to as well.
    final populated = <List<Widget>>[
      columns.civicSignal,
      columns.ecosystem,
      columns.continuity,
    ].where((c) => c.isNotEmpty).toList();

    if (populated.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < populated.length; i++) ...[
          Expanded(child: _DiscoveryColumn(modules: populated[i])),
          if (i != populated.length - 1) const SizedBox(width: AuraSpace.s16),
        ],
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
