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

  static const double maxWidth = 1080;

  static const _groups = [
    _FooterGroup('About Aura', [
      _FooterLink('Mission', '/mission'),
      _FooterLink('White Paper', '/white-paper'),
      _FooterLink('Founder', '/founder'),
    ]),
    _FooterGroup('Participation', [
      _FooterLink('Supporters', '/supporters'),
      _FooterLink('Patrons', '/patrons'),
      _FooterLink('Investors', '/investors'),
    ]),
    _FooterGroup('Support', [
      _FooterLink('Support', '/support/agent'),
    ]),
    _FooterGroup('Legal', [
      _FooterLink('Privacy', '/privacy'),
      _FooterLink('Terms', '/terms'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AuraGradients.footer,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s20,
              AuraSpace.s24,
              AuraSpace.s20,
              AuraSpace.s20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                flex: 5,
                                child: _FooterIdentity(),
                              ),
                              const SizedBox(width: AuraSpace.s32),
                              Expanded(
                                flex: 7,
                                child: _FooterGroups(groups: _groups),
                              ),
                            ],
                          )
                        : const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FooterIdentity(),
                              SizedBox(height: AuraSpace.s24),
                              _FooterGroups(groups: _groups),
                            ],
                          );
                  },
                ),
                const SizedBox(height: AuraSpace.s20),
                const Divider(color: AuraSurface.divider, height: 1),
                const SizedBox(height: AuraSpace.s14),
                Text(
                  '© $year Aura. Structured communication for people and institutions.',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterIdentity extends StatelessWidget {
  const _FooterIdentity();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraShellWordmark(onTap: () => context.go('/public')),
        const SizedBox(height: AuraSpace.s10),
        Text(
          'Structured communication for people and institutions.',
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        const Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            _TrustPill('Verified identities'),
            _TrustPill('Institution-ready'),
            _TrustPill('No noise'),
          ],
        ),
      ],
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.elevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FooterGroups extends StatelessWidget {
  const _FooterGroups({required this.groups});

  final List<_FooterGroup> groups;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groups.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? 2 : 4,
            mainAxisSpacing: AuraSpace.s18,
            crossAxisSpacing: AuraSpace.s16,
            mainAxisExtent: 118,
          ),
          itemBuilder: (context, index) => _FooterGroupColumn(group: groups[index]),
        );
      },
    );
  }
}

class _FooterGroupColumn extends StatelessWidget {
  const _FooterGroupColumn({required this.group});

  final _FooterGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.title,
          style: AuraText.micro.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        ...group.links.map((link) => _FooterButton(link: link)),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({required this.link});

  final _FooterLink link;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => context.go(link.path),
        style: TextButton.styleFrom(
          foregroundColor: AuraSurface.muted,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
        ),
        child: Text(
          link.label,
          style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _FooterGroup {
  const _FooterGroup(this.title, this.links);

  final String title;
  final List<_FooterLink> links;
}

class _FooterLink {
  const _FooterLink(this.label, this.path);

  final String label;
  final String path;
}
