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

class ShellFooter extends StatelessWidget {
  const ShellFooter({super.key});

  static const double maxWidth = 1080;

  static const _links = [
    _FooterLink('Support', '/support/agent'),
    _FooterLink('Privacy', '/privacy'),
    _FooterLink('Terms', '/terms'),
  ];

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
              vertical: AuraSpace.s20,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _FooterWordmark(),
                      const Spacer(),
                      const _FooterNavLinks(links: _links),
                      const SizedBox(width: AuraSpace.s20),
                      Text(
                        '© $year Aura',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.faint,
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FooterWordmark(),
                    const SizedBox(height: AuraSpace.s16),
                    const _FooterNavLinks(links: _links),
                    const SizedBox(height: AuraSpace.s12),
                    Text(
                      '© $year Aura',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.faint,
                      ),
                    ),
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

class _FooterWordmark extends StatelessWidget {
  const _FooterWordmark();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/public'),
      child: SvgPicture.asset(
        'assets/brand/AURA_logo_master.svg',
        height: 20,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _FooterNavLinks extends StatelessWidget {
  const _FooterNavLinks({required this.links});

  final List<_FooterLink> links;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s4,
      runSpacing: AuraSpace.s4,
      children: links
          .map(
            (link) => TextButton(
              onPressed: () => context.go(link.path),
              style: TextButton.styleFrom(
                foregroundColor: AuraSurface.muted,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: AuraSpace.s4,
                ),
              ),
              child: Text(
                link.label,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.path);

  final String label;
  final String path;
}
