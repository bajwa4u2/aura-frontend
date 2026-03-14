import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';

class MeSection extends StatelessWidget {
  const MeSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      Text(title, style: AuraText.title),
      const SizedBox(height: AuraSpace.s10),
      AuraCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: _withDividers(children),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final out = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);

      if (i != children.length - 1) {
        out.add(
          const Divider(
            height: 1,
            thickness: 1,
            color: AuraSurface.divider,
          ),
        );
      }
    }

    return out;
  }
}

class MeSectionRow extends StatelessWidget {
  const MeSectionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leading,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final IconData? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: active ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s14,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(
                  leading,
                  size: 18,
                  color: active ? AuraSurface.ink : AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active ? AuraSurface.ink : AuraSurface.muted,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null && trailing!.trim().isNotEmpty) ...[
                Text(
                  trailing!,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
              ],
              Icon(
                Icons.chevron_right,
                size: 18,
                color: active ? AuraSurface.muted : AuraSurface.divider,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
