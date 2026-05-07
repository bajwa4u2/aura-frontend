import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

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
  static const double _wideBreakpoint = 760;

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
    final copy = Text(
      '© $year Aura',
      style: AuraText.micro.copyWith(color: AuraSurface.faint),
    );
    final tagline = Text(
      'Public discourse · accountable participation',
      style: AuraText.micro.copyWith(color: AuraSurface.faint),
    );

    if (wide) {
      return Row(
        children: [
          copy,
          const Spacer(),
          tagline,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        copy,
        const SizedBox(height: AuraSpace.s4),
        tagline,
      ],
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.path);

  final String label;
  final String path;
}
