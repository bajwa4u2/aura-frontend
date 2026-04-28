import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/aura_design_system.dart';
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

class ShellFooter extends StatelessWidget {
  const ShellFooter({super.key});

  static const double _maxWidth = 1080; // 920 + 160

  static const _links = [
    _Link('Mission', '/mission'),
    _Link('Institutions', '/institutions'),
    _Link('Investors', '/investors'),
    _Link('Patrons', '/patrons'),
    _Link('Supporters', '/supporters'),
    _Link('Support', '/support/agent'),
    _Link('Privacy', '/privacy'),
    _Link('Terms', '/terms'),
    _Link('White Paper', '/white-paper'),
    _Link('Founder', '/founder'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AuraGradients.footer,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16, AuraSpace.s14, AuraSpace.s16, AuraSpace.s14),
            child: Wrap(
              spacing: AuraSpace.s2,
              runSpacing: AuraSpace.s4,
              children: _links.map((l) => _FooterBtn(link: l)).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterBtn extends StatelessWidget {
  const _FooterBtn({required this.link});

  final _Link link;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(link.path),
      style: TextButton.styleFrom(
        foregroundColor: AuraSurface.faint,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s6, vertical: AuraSpace.s4),
      ),
      child: Text(
        link.label,
        style: AuraText.micro.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Link {
  const _Link(this.label, this.path);

  final String label;
  final String path;
}
