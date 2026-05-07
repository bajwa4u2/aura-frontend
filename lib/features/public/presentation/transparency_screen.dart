import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../institutions/ui/institution_ds.dart';
import '../domain/monetization_kind.dart';

/// `/aura/participation` — public transparency page.
///
/// Single source of truth for what users, institutions, and the
/// platform owe each other. Anchored sections so any in-context
/// monetization label can land here scrolled to its own explanation.
///
/// Static, prose-driven, calm. No marketing tone. No upsell. The
/// pricing link routes to the existing institution billing surface
/// (already public knowledge for institution admins) without
/// rewriting any backend pricing logic.
class TransparencyScreen extends StatelessWidget {
  const TransparencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: InsScreen(
        children: [
          const InsModeHeader(
            title: 'How Aura works',
            description:
                'Public discourse, accountable institutions, transparent monetization.',
          ),
          const InsModeHeaderGap(),

          // ── A. Aura is layered ─────────────────────────────────
          const _SectionTitle('Aura is layered'),
          const SizedBox(height: AuraSpace.s10),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 760 ? 3 : 1;
              const gap = AuraSpace.s12;
              final tileWidth = (w - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: const _LayerTile(
                      title: 'Personal',
                      body:
                          'Private — only you can see it. Drafts and notes live here.',
                      icon: Icons.lock_outline_rounded,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: const _LayerTile(
                      title: 'Social',
                      body:
                          'Visible to people you’re connected with or the space you posted to.',
                      icon: Icons.people_outline_rounded,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: const _LayerTile(
                      title: 'Public',
                      body:
                          'Open discourse. Anyone on Aura can see and reply, with attribution.',
                      icon: Icons.public_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
          const InsSectionGap(),

          // ── B. Anyone can speak ────────────────────────────────
          const _SectionTitle('Anyone can speak'),
          const SizedBox(height: AuraSpace.s8),
          const _Para(
            'Any verified Aura account can post, reply, and host live '
            'sessions. There is no paywall on participation. The Public '
            'layer is the same surface for everyone — institutions are '
            'voices in it, not owners of it.',
          ),
          const InsSectionGap(),

          // ── C. What institutions can do free ───────────────────
          const _SectionTitle('What institutions can do (free)'),
          const SizedBox(height: AuraSpace.s8),
          const _Bulleted(items: [
            'Verify the institution’s identity and a primary domain.',
            'Post statements, advisories, notices, and updates.',
            'Reply to public threads as an Official voice.',
            'Host live sessions of any type (briefing, class, research, '
                'media, internal meeting).',
          ]),
          const InsSectionGap(),

          // ── D. What institutions can buy (paid, labeled) ──────
          const _SectionTitle(
            'What institutions can buy (paid — always labeled in-context)',
          ),
          const SizedBox(height: AuraSpace.s8),
          const _Para(
            'Paid actions are visible everywhere they appear. A reader '
            'should never have to go off-screen to figure out whether an '
            'amplification was paid for. The labels you see in the feed '
            'and threads are the same labels institutions buy under:',
          ),
          const SizedBox(height: AuraSpace.s12),
          for (final entry in const [
            _PaidEntry(
              kind: MonetizationKind.officialResponse,
              what:
                  'Free, included with verified status — not a purchase.',
              consequence:
                  'A reply from the institution carries the OFFICIAL '
                  'RESPONSE label and a verified glyph.',
            ),
            _PaidEntry(
              kind: MonetizationKind.priorityResponse,
              what: 'Pin one institutional reply to the top of a public '
                  'thread for a fixed window (typically 24 hours).',
              consequence:
                  'The pinned reply renders with the PRIORITY · PAID '
                  'label so every reader sees that the placement was '
                  'paid for.',
            ),
            _PaidEntry(
              kind: MonetizationKind.hostedSession,
              what:
                  'Run a public live session with extended capacity, '
                  'recording retention, and broadcast-grade defaults.',
              consequence:
                  'Public Briefing / Media Interaction sessions render '
                  'the OFFICIAL BROADCAST chip in the call header. '
                  'Recording rules are visible to participants on join.',
            ),
            _PaidEntry(
              kind: MonetizationKind.paidDistribution,
              what:
                  'Boost reach of a public post into the global discourse '
                  'feed.',
              consequence:
                  'Boosted posts render the PAID DISTRIBUTION label '
                  'so readers can distinguish boost from organic momentum.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s10),
              child: _PaidActionCard(entry: entry),
            ),
          const InsSectionGap(),

          // ── E. Accountability ──────────────────────────────────
          const _SectionTitle('What institutions are accountable for'),
          const SizedBox(height: AuraSpace.s8),
          const _Bulleted(items: [
            'Identity verification: domains, name, and a real human '
                'representative are bound to the account.',
            'Truth claims: factual claims in announcements may be '
                'reviewed; abuses can be enforced against publicly.',
            'Misuse of paid actions: paid placements that violate the '
                'public discourse rules can be reversed and refunded.',
            'Public correction: institutions are expected to correct '
                'their own statements where errors are identified.',
          ]),
          const InsSectionGap(),

          // ── F. Pricing ────────────────────────────────────────
          const _SectionTitle('Pricing'),
          const SizedBox(height: AuraSpace.s8),
          const _Para(
            'Each institution sees its own pricing inside its workspace '
            'billing screen. Pricing varies by plan and region; the '
            'same pricing applies to every institution in the same '
            'plan. There is no individualized pricing.',
          ),
          const SizedBox(height: AuraSpace.s24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _Para extends StatelessWidget {
  const _Para(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AuraText.body.copyWith(
        color: AuraSurface.muted,
        height: 1.55,
      ),
    );
  }
}

class _Bulleted extends StatelessWidget {
  const _Bulleted({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7, right: 8),
                  child: Icon(
                    Icons.fiber_manual_record,
                    size: 6,
                    color: AuraSurface.faint,
                  ),
                ),
                Expanded(
                  child: Text(
                    t,
                    style: AuraText.body.copyWith(
                      color: AuraSurface.muted,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Icon(icon, size: 18, color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaidEntry {
  const _PaidEntry({
    required this.kind,
    required this.what,
    required this.consequence,
  });

  final MonetizationKind kind;
  final String what;
  final String consequence;
}

class _PaidActionCard extends StatelessWidget {
  const _PaidActionCard({required this.entry});

  final _PaidEntry entry;

  @override
  Widget build(BuildContext context) {
    final paid = entry.kind.isPaid;
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: paid
              ? AuraSurface.divider
              : AuraSurface.accent.withValues(alpha: 0.3),
          width: paid ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: paid
                      ? AuraSurface.subtle
                      : AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(
                    color: paid
                        ? AuraSurface.divider
                        : AuraSurface.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      paid
                          ? Icons.attach_money_rounded
                          : Icons.verified_rounded,
                      size: 12,
                      color: paid
                          ? AuraSurface.muted
                          : AuraSurface.accentText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.kind.stripeLabel,
                      style: AuraText.micro.copyWith(
                        color: paid
                            ? AuraSurface.muted
                            : AuraSurface.accentText,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            entry.kind.label,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'What it is — ${entry.what}',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How it shows up — ${entry.consequence}',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
