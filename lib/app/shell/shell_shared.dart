import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/aura_responsive.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WORDMARK
// ─────────────────────────────────────────────────────────────────────────────

class AuraShellWordmark extends StatelessWidget {
  const AuraShellWordmark({super.key, required this.onTap});

  final VoidCallback onTap;

  static const String _logoAsset = 'assets/brand/AURA_logo_master.svg';
  static const double _logoHeight = 40;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Aura',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s4,
            vertical: AuraSpace.s4,
          ),
          child: SvgPicture.asset(
            _logoAsset,
            height: _logoHeight,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────

/// THE PUBLIC CLOSING.
///
/// ── WHAT THIS REPLACES ──────────────────────────────────────────────────────
///
/// A sitemap. Three link columns headed Aura / Support / Legal, a paragraph
/// defining the platform, an attribution lockup and a continuity row — five
/// separate blocks, each individually reasonable, together a warehouse. It
/// ended the page the way a corporate site ends a page: by listing itself.
///
/// A public surface's last movement is the last thing a visitor reads. It is
/// the natural place to say what the product is FOR and to offer the one act
/// that follows from believing it. Everything else is context and belongs
/// quietly underneath.
///
/// ── THE MOVEMENT ────────────────────────────────────────────────────────────
///
///   1. the mark, and one authored thought
///   2. the invitation — Start a conversation
///   3. a short line of destinations that genuinely earn a place
///   4. a quiet line: product, company, legal, ecosystem
///
/// ── WHAT WAS DELIBERATELY NOT CARRIED OVER ──────────────────────────────────
///
///   * "Contact". `/contact` is a redirect to the support agent, so the
///     footer offered two names for one destination and taught people that
///     Contact and Help were different places. Founder ruling: contact is
///     retired as public taxonomy and the relationship path is Start a
///     conversation. Both names converge on the one real surface.
///   * Column HEADINGS. Three headings above one or two links each is
///     scaffolding for a structure that is not there.
///   * The platform definition paragraph. A closing invites; it does not
///     re-explain.
///
/// Owned by `PublicShell` and the public document/publication layouts.
/// Workspace shells (Member / Institution / Admin) MUST NOT render it.
class ShellFooter extends StatelessWidget {
  const ShellFooter({super.key});

  /// The closing sits on the page's own edges.
  ///
  /// It was set to a narrower band of its own, which read well in isolation
  /// and wrongly in place: the closing's left edge stood 190 px inside the
  /// left edge of every section above it, so the last movement of the page
  /// looked like a different page. A closing that does not line up with what
  /// it closes is not a closing.
  ///
  /// The PROSE is still held to a reading measure (see
  /// [_closingThoughtMeasure]), which is the part that actually needed
  /// narrowing.
  static const double maxWidth = kHeroWidth;

  /// A closing thought set across 1300 px reads as a banner. The band is the
  /// page's; the sentence inside it is sized to be read.
  static const double _closingThoughtMeasure = 620;

  /// Below this the closing stacks. A content test on the footer's own width,
  /// not a viewport breakpoint — the footer is rendered inside containers of
  /// several widths across the public estate.
  static const double _wideBreakpoint = 760;

  /// THE CLOSING THOUGHT.
  ///
  /// Public-first by construction and in the doctrine's own order: people and
  /// what they say come first, continuity second, institutional
  /// accountability last and as a consequence rather than a premise. It
  /// claims no capability Aura does not have and names no institution as the
  /// reason to be here.
  static const _closingThought =
      'Say it in the open, and let it keep its meaning. Conversations here '
      'hold on to who spoke and what was promised. When an institution '
      'takes part, it answers on the same record.';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The estate's shared support band sits ABOVE the closing, which is
        // where the company site, Orchestrate and Bajwa Writes all put it.
        const _MadeWithSupportBand(),
        _closing(context),
      ],
    );
  }

  Widget _closing(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s20,
              vertical: AuraSpace.s32,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ClosingInvitation(wide: wide),
                    const SizedBox(height: AuraSpace.s24),
                    const _ClosingDestinations(),
                    const SizedBox(height: AuraSpace.s24),
                    Container(height: 1, color: AuraSurface.divider),
                    const SizedBox(height: AuraSpace.s16),
                    _QuietLine(wide: wide),
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

/// The mark, the thought, and the one act that follows from it.
/// MADE WITH SUPPORT: the estate's shared band, in Aura's palette.
///
/// Not a new invention. The company site, Orchestrate and Bajwa Writes all
/// close the same way: a full-bleed field above the footer carrying a small
/// letterspaced label, one sentence naming the environment the product is
/// being built in, and the three programme marks ranged to the trailing edge.
/// Aura was the only surface in the estate without it, which is the sort of
/// gap that makes three products look like three companies.
///
/// WHAT IS TAKEN EXACTLY, and why:
///
///   * THE MARKS are the same original files, copied from the sibling
///     repositories rather than re-exported. Three slightly different
///     renderings of a partner's logo across one estate is worse than none.
///   * THE GEOMETRY is the siblings': 132 / 110 / 94 wide at desktop and
///     110 / 82 / 76 compact, all on a 42 px line, contained, ranged to the
///     end with 22 px between them. Marks set at different sizes on
///     different products read as three separate arrangements.
///   * THE SENTENCE follows the construction the other two use, so the three
///     read as one house saying the same thing about three products.
///
/// WHAT DIFFERS, deliberately:
///
///   * THE FIELD is Aura's, not Bajwa Writes' teal or Orchestrate's slate.
///     Parity of composition, not of palette: each product closes in its own
///     colour, in the same shape.
///   * THE MARKS ARE LINKS. Neither Flutter sibling links them; the COMPANY
///     estate does. A reader who wants to check a claim about who supports
///     this work should be able to, so where the two disagree this follows
///     the company.
class _MadeWithSupportBand extends StatelessWidget {
  const _MadeWithSupportBand();

  /// Below this the label and the marks stack. The siblings' own threshold.
  static const double _compactBreakpoint = 760;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(
          top: BorderSide(color: AuraSurface.divider),
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kHeroWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s20,
              vertical: AuraSpace.s24,
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < _compactBreakpoint;
                final copy = _copy();
                final marks = _SupportMarks(compact: compact);
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      const SizedBox(height: AuraSpace.s16),
                      marks,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: AuraSpace.s24),
                    Flexible(child: marks),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _copy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MADE WITH SUPPORT',
          style: AuraText.micro.copyWith(
            color: AuraSurface.accentText,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'Aura is being built in an environment that values durable public '
          'communication.',
          style: AuraText.body.copyWith(
            color: AuraSurface.ink,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SupportMarks extends StatelessWidget {
  const _SupportMarks({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: compact ? WrapAlignment.start : WrapAlignment.end,
      spacing: compact ? 12 : 22,
      runSpacing: 16,
      children: [
        // A MARK MAY STAND FOR A PROGRAMME ONLY IF IT IS THAT PROGRAMME'S
        // MARK. Two of these were not, and were removed rather than redrawn.
        //
        //   google-for-startups.svg was the plain Google "G" from the Simple
        //   Icons set — its own <title> said `Google` — sitting under a label
        //   naming a programme it does not represent.
        //
        //   aws-activate.svg was an AWS ARCHITECTURE DIAGRAM icon,
        //   `Icon-Architecture/48/Arch_AWS-Activate_48`, drawn on the magenta
        //   #C925D1 "Customer Enablement" category tile that set uses inside
        //   diagrams. At 42px it read as a magenta square. That icon set is
        //   not licensed as programme badges.
        //
        // The relationships are real and recorded, so the WORDS stay. Only the
        // pictures were untrue, and a fabricated replacement would have been
        // the same offence with better craft. Where an official asset is
        // established, a mark can return here.
        _SupportMark(
          asset: 'assets/branding/support/microsoft-for-startups-badge.png',
          label: 'Microsoft for Startups',
          url: 'https://www.microsoft.com/en-us/startups/',
          width: compact ? 110 : 132,
        ),
        const _SupportWordmark(
          label: 'Google for Startups',
          url: 'https://startup.google.com/',
        ),
        const _SupportWordmark(
          label: 'AWS Activate',
          url: 'https://aws.amazon.com/activate/',
        ),
      ],
    );
  }
}

/// A supporter named in the product's own type, for a relationship that is
/// real but has no legitimate mark to show.
///
/// Deliberately the SAME 42px row height as a badge, so the strip reads as
/// three considered entries rather than one image and two holes. Setting it in
/// Aura's own type is also the honest form: it claims a relationship, which is
/// true, and does not imply an endorsed asset, which would not be.
class _SupportWordmark extends StatelessWidget {
  const _SupportWordmark({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      child: InkWell(
        onTap: () => _openExternal(url),
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 42,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              label,
              style: AuraText.micro.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportMark extends StatelessWidget {
  const _SupportMark({
    required this.asset,
    required this.label,
    required this.url,
    required this.width,
  });

  final String asset;
  final String label;
  final String url;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => _openExternal(url),
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: width,
            height: 42,
            // The marks sit free on the field. A white plate behind them
            // reads as three pasted image cards on a dark closing.
            child: asset.endsWith('.svg')
                ? SvgPicture.asset(asset, fit: BoxFit.contain)
                : Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    // A missing partner mark must not become a broken tile in
                    // the estate's closing. Name it in text instead.
                    errorBuilder: (context, error, stack) => Text(
                      label,
                      style: AuraText.micro.copyWith(color: AuraSurface.muted),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ClosingInvitation extends StatelessWidget {
  const _ClosingInvitation({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final thought = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // THE AURA PRODUCT MARK — the gold ring with its eight radial ticks,
        // from the identity master. Not the Aura Platform LLC company mark:
        // this is the product closing its own public surface, and the company
        // appears quietly below where it belongs.
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ShellFooter._closingThoughtMeasure,
          ),
          child: Text(
            ShellFooter._closingThought,
            style: AuraText.body.copyWith(color: AuraSurface.ink, height: 1.6),
          ),
        ),
      ],
    );

    final invitation = _StartAConversationButton();

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: thought),
          const SizedBox(width: AuraSpace.s32),
          invitation,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        thought,
        const SizedBox(height: AuraSpace.s20),
        invitation,
      ],
    );
  }
}

/// START A CONVERSATION — the canonical relationship path.
///
/// One destination, deliberately. `/contact` was a route that redirected here
/// and "Help" was a second name for the same place; a public surface offering
/// three doors into one room is not offering choice, it is offering doubt.
class _StartAConversationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start a conversation',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/support/agent'),
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s20,
              vertical: AuraSpace.s12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(
                color: AuraSurface.accent.withValues(alpha: 0.45),
              ),
              color: AuraSurface.accentSoft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start a conversation',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AuraSpace.s8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AuraSurface.accentText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The destinations that earn a place in a closing.
///
/// Three, on one line, with no headings. Each answers a question a public
/// visitor actually has at the end of a public page: what is this for
/// (Mission), what is happening (Discover), who is accountable here
/// (Institutions). Routes exist for a great deal more; existing is not a
/// reason to be listed.
class _ClosingDestinations extends StatelessWidget {
  const _ClosingDestinations();

  static const _destinations = <_FooterLink>[
    _FooterLink('Mission', '/mission'),
    _FooterLink('Discover', '/discover'),
    _FooterLink('Institutions', '/institutions'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s20,
      runSpacing: AuraSpace.s8,
      children: [
        for (final d in _destinations) _FooterNavLink(link: d, emphasis: true),
      ],
    );
  }
}

/// THE BOTTOM ROW, at parity with the estate.
///
/// Orchestrate and Bajwa Writes close on the identical shape: a rule, then
/// the company name set bold at the leading edge with its relationship line
/// beneath it, and the SIBLING products ranged to the trailing edge. Both
/// omit themselves from that row.
///
/// That resolves a tension worth recording. The five-link band this replaces
/// was retired here because Aura's closing is not a corporate portfolio
/// directory and Aura does not link to itself. Both remain true, and the
/// estate's own shape already honours the second one: what the siblings carry
/// is not a directory of everything, it is the two OTHER products and the
/// founder. Aura carrying the same three, and no self-link, is what parity
/// actually asks for.
///
/// Legal sits under the company name rather than in a column of its own,
/// because Aura's closing has no columns to put it in.
class _QuietLine extends StatelessWidget {
  const _QuietLine({required this.wide});

  final bool wide;

  /// The estate, minus Aura. Same order and same omission-of-self the two
  /// sibling products use.
  static const _siblings = <_ExternalLink>[
    _ExternalLink('Orchestrate', 'https://orchestrateops.com'),
    _ExternalLink('Bajwa Writes', 'https://bajwawrites.com'),
    _ExternalLink('Founder', 'https://bajwa.auraplatform.org'),
  ];

  @override
  Widget build(BuildContext context) {
    // THE COMPANY IS NAMED ONCE, AND IT IS THE LINK.
    //
    // This block said it twice in three lines: a bold "Aura Platform LLC"
    // and then "Aura is part of Aura Platform LLC" directly beneath it. That
    // was the legacy attribution lockup surviving inside a new composition,
    // which is the failure mode of editing a footer instead of replacing it.
    //
    // The shape is now the estate's. Orchestrate closes on the product name
    // over "A product of Aura Platform LLC.", and Aura closes the same way,
    // with the company line carrying the link to the company. The Aura mark
    // went too: this closing is already on an Aura page, and a product does
    // not need to show a visitor its own logo to sign off.
    //
    // No copyright line. Neither sibling prints one, and the company name is
    // the attribution.
    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Aura',
          style: AuraText.small.copyWith(
            color: AuraSurface.ink,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        const _ExternalNavLink(
          link: _ExternalLink(
            'A product of Aura Platform LLC.',
            _kEcosystemCompanyUrl,
          ),
        ),
      ],
    );

    // Legal and the rest of the estate travel together at the trailing edge,
    // in one quiet run. Aura has no link columns to file Privacy and Terms
    // into, so this is where they live.
    final trailing = Wrap(
      spacing: AuraSpace.s16,
      runSpacing: 4,
      alignment: wide ? WrapAlignment.end : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _FooterNavLink(link: _FooterLink('Privacy', '/privacy')),
        const _FooterNavLink(link: _FooterLink('Terms', '/terms')),
        for (final l in _siblings) _ExternalNavLink(link: l),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: brand),
          const SizedBox(width: AuraSpace.s24),
          trailing,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        brand,
        const SizedBox(height: AuraSpace.s12),
        trailing,
      ],
    );
  }
}

class _ExternalLink {
  const _ExternalLink(this.label, this.url);
  final String label;
  final String url;
}

class _ExternalNavLink extends StatelessWidget {
  const _ExternalNavLink({required this.link});

  final _ExternalLink link;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: 'Open ${link.label}',
      child: InkWell(
        onTap: () => _openExternal(link.url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            link.label,
            style: AuraText.micro.copyWith(color: AuraSurface.muted),
          ),
        ),
      ),
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.path);
  final String label;
  final String path;
}

class _FooterNavLink extends StatelessWidget {
  const _FooterNavLink({required this.link, this.emphasis = false});

  final _FooterLink link;

  /// A destination reads slightly forward of the legal line beneath it.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: link.label,
      child: InkWell(
        onTap: () => context.go(link.path),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            link.label,
            style: emphasis
                ? AuraText.small.copyWith(
                    color: AuraSurface.ink,
                    fontWeight: FontWeight.w600,
                  )
                : AuraText.micro.copyWith(color: AuraSurface.muted),
          ),
        ),
      ),
    );
  }
}

// AURA'S CLOSING IS NOT A CORPORATE PORTFOLIO DIRECTORY.
//
// A five-link band lived here — Company · Aura · Orchestrate · Bajwa Writes ·
// Founder — and it was carried forward through every footer revision because
// it was recorded as doctrine-locked. Audited on the founder's instruction,
// each link answers for itself poorly at the foot of Aura:
//
//   * AURA linked Aura to Aura. A "you are here" marker in a five-item row is
//     navigation furniture, not orientation.
//   * ORCHESTRATE and BAJWA WRITES are separate products with their own
//     audiences. Advertising them to someone reading a public Aura page is a
//     company-level decision, and the company estate is where it belongs.
//   * FOUNDER is a route, and a route existing has never been a reason for
//     permanent public taxonomy.
//
// What a visitor legitimately gains at this point is knowing WHO BUILDS THIS.
// That survives, as one quiet line linking to the company — which is itself
// the entrance to the portfolio for anyone who wants it. Aura owns Aura.

const String _kEcosystemCompanyUrl = 'https://company.auraplatform.org';

Future<void> _openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}
