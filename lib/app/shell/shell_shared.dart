import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_responsive.dart';
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
              horizontal: AuraSpace.s4, vertical: AuraSpace.s4),
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

/// Phase 6.5 — product-grade public footer.
///
/// Owned by `PublicShell` only. Workspace shells (Member / Institution /
/// Admin) MUST NOT render this widget. Renders four short link columns plus
/// a calm platform note, in a dark, restrained surface aligned with the
/// Aura design system.
class ShellFooter extends StatelessWidget {
  const ShellFooter({super.key});

  static const double maxWidth = 1080;
  // Tablet/desktop transition for the footer's 4-column → stacked
  // collapse. Aligned with the canonical tablet breakpoint so the
  // footer transitions at the same width as the shell.
  static const double _wideBreakpoint = kTabletBreak; // 900

  static const _platformNote =
      'Aura is public discourse infrastructure. People raise issues, '
      'institutions respond, and outcomes are public.';

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

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
              vertical: AuraSpace.s28,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                // Reconciled 2026-06-01 — see
                // docs/ecosystem/FOOTER_RECONCILIATION_2026-06-01.md
                // in the personal repo. The earlier two-slab footer
                // (4 columns → bottom row → separate ecosystem band)
                // read as two stacked footers. The ecosystem is now
                // integrated into `_FooterBottomRow` (institution
                // lockup left, canonical links right) — one footer,
                // closing in two layers within one container.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FooterTopRow(wide: wide),
                    const SizedBox(height: AuraSpace.s24),
                    Container(
                      height: 1,
                      color: AuraSurface.divider,
                    ),
                    const SizedBox(height: AuraSpace.s16),
                    _FooterBottomRow(year: year, wide: wide),
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

class _FooterTopRow extends StatelessWidget {
  const _FooterTopRow({required this.wide});

  final bool wide;

  static const _columns = <_FooterColumn>[
    _FooterColumn(title: 'Aura', links: [
      _FooterLink('Mission', '/mission'),
      _FooterLink('Founder', '/founder'),
      _FooterLink('White paper', '/white-paper'),
    ]),
    _FooterColumn(title: 'Participation', links: [
      _FooterLink('Supporters', '/supporters'),
      _FooterLink('Patrons', '/patrons'),
      _FooterLink('Investors', '/investors'),
    ]),
    _FooterColumn(title: 'Support', links: [
      _FooterLink('Contact', '/contact'),
      _FooterLink('Help', '/support/agent'),
    ]),
    _FooterColumn(title: 'Legal', links: [
      _FooterLink('Privacy', '/privacy'),
      _FooterLink('Terms', '/terms'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final brand = _BrandBlock(wide: wide);

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: brand),
          const SizedBox(width: AuraSpace.s32),
          Expanded(
            flex: 6,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _columns.length; i++) ...[
                  Expanded(child: _columns[i]),
                  if (i != _columns.length - 1)
                    const SizedBox(width: AuraSpace.s20),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        brand,
        const SizedBox(height: AuraSpace.s24),
        const Wrap(
          spacing: AuraSpace.s32,
          runSpacing: AuraSpace.s24,
          children: _columns,
        ),
      ],
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => context.go('/'),
          child: SvgPicture.asset(
            'assets/brand/AURA_logo_master.svg',
            height: 22,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 320 : 480),
          child: Text(
            ShellFooter._platformNote,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLink> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AuraText.micro.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        for (final link in links) _FooterNavLink(link: link),
      ],
    );
  }
}

class _FooterNavLink extends StatelessWidget {
  const _FooterNavLink({required this.link});

  final _FooterLink link;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s6),
      child: InkWell(
        onTap: () => context.go(link.path),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            link.label,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterBottomRow extends StatelessWidget {
  const _FooterBottomRow({required this.year, required this.wide});

  final int year;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    // Institutional attribution lockup — wordmark linked to the
    // company surface, plus the Aura-specific attribution copy.
    // Replaces the previous free-floating "© $year Aura" line; year
    // moves into the attribution caption so the visual weight of the
    // institution sits where the surface closes.
    final lockup = InkWell(
      onTap: () => _openExternal('https://company.auraplatform.org'),
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Aura Platform LLC',
              style: AuraText.small.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Built by Aura Platform LLC · © $year',
              style: AuraText.micro.copyWith(color: AuraSurface.muted),
            ),
          ],
        ),
      ),
    );

    // Inline continuity row — five canonical links in doctrine-locked
    // order. The current surface (Aura) is the "you are here" marker
    // and is not tappable.
    const links = _AuraEcosystemRow(currentSlug: 'aura');

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          lockup,
          const Spacer(),
          links,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        lockup,
        const SizedBox(height: AuraSpace.s8),
        links,
      ],
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.path);

  final String label;
  final String path;
}

// ─────────────────────────────────────────────────────────────────────────────
// ECOSYSTEM CONTINUITY BAND
// ─────────────────────────────────────────────────────────────────────────────
//
// Renders the canonical institutional band at the foot of the public shell.
// See docs/ecosystem/ECOSYSTEM_CONTINUITY_ARCHITECTURE.md in the personal
// repo for the doctrine this implements.
//
// Layout: two layers in one row.
//   Left  — institution lockup: "Aura Platform LLC" wordmark linked to
//           the company site, plus Aura's attribution copy below it.
//   Right — five canonical links in doctrine-locked order
//           (Company → Aura → Orchestrate → Bajwa Writes → Founder),
//           with the current surface (Aura) marked as the
//           "you are here" link.
//
// Tone: restrained mono-style typography, smaller than the surface-
// native footer above it. The band orients without competing.

class _EcosystemEntry {
  const _EcosystemEntry({
    required this.slug,
    required this.label,
    required this.url,
  });
  final String slug;
  final String label;
  final String url;
}

const String _kEcosystemCompanyUrl = 'https://company.auraplatform.org';

const List<_EcosystemEntry> _kEcosystemLinks = <_EcosystemEntry>[
  _EcosystemEntry(slug: 'company',      label: 'Company',      url: _kEcosystemCompanyUrl),
  _EcosystemEntry(slug: 'aura',         label: 'Aura',         url: 'https://auraplatform.org'),
  _EcosystemEntry(slug: 'orchestrate',  label: 'Orchestrate',  url: 'https://orchestrateops.com'),
  _EcosystemEntry(slug: 'bajwa-writes', label: 'Bajwa Writes', url: 'https://bajwawrites.com'),
  _EcosystemEntry(slug: 'founder',      label: 'Founder',      url: 'https://bajwa.auraplatform.org'),
];

class _AuraEcosystemRow extends StatelessWidget {
  const _AuraEcosystemRow({required this.currentSlug});
  final String currentSlug;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < _kEcosystemLinks.length; i++) ...[
          if (i > 0)
            Text('·',
                style: AuraText.micro.copyWith(color: AuraSurface.faint)),
          _EcosystemLink(
            link: _kEcosystemLinks[i],
            currentSlug: currentSlug,
          ),
        ],
      ],
    );
  }
}

class _EcosystemLink extends StatelessWidget {
  const _EcosystemLink({required this.link, required this.currentSlug});
  final _EcosystemEntry link;
  final String currentSlug;

  @override
  Widget build(BuildContext context) {
    final isCurrent = link.slug == currentSlug;
    final style = AuraText.micro.copyWith(
      color: isCurrent ? AuraSurface.ink : AuraSurface.muted,
      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
      decoration: isCurrent ? TextDecoration.underline : TextDecoration.none,
      decorationColor: AuraSurface.divider,
      decorationThickness: 1.2,
    );
    if (isCurrent) {
      return Semantics(
        selected: true,
        label: '${link.label} (current surface)',
        child: Text(link.label, style: style),
      );
    }
    return Semantics(
      link: true,
      label: 'Open ${link.label} surface',
      child: InkWell(
        onTap: () => _openExternal(link.url),
        child: Text(link.label, style: style),
      ),
    );
  }
}

Future<void> _openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}
