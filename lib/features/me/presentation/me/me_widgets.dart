import 'package:flutter/material.dart';

import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../../core/ui/aura_text_block.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECORD ITEM CARD
// ─────────────────────────────────────────────────────────────────────────────

class MeRecordItemCard extends StatelessWidget {
  const MeRecordItemCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s16),
        decoration: BoxDecoration(
          color: AuraSurface.elevated,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AuraSurface.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Icon(icon, size: 18, color: AuraSurface.ink),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuraTextBlock(
                    title,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AuraTextBlock(
                      subtitle!.trim(),
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (trailingLabel != null &&
                      trailingLabel!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AuraTextBlock(
                      trailingLabel!.trim(),
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (enabled)
              const Padding(
                padding: EdgeInsets.only(left: AuraSpace.s8, top: 2),
                child: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: AuraSurface.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION
// ─────────────────────────────────────────────────────────────────────────────

List<Widget> _withDividers(List<Widget> children) {
  final items = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    items.add(children[i]);
    if (i != children.length - 1) {
      items.add(
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
          color: AuraSurface.divider,
        ),
      );
    }
  }
  return items;
}

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
    final visibleChildren = children
        .where((child) => child is! SizedBox)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AuraText.title),
            const SizedBox(height: AuraSpace.s14),
            ..._withDividers(visibleChildren),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS ITEM
// ─────────────────────────────────────────────────────────────────────────────

class MeSettingsItem extends StatelessWidget {
  const MeSettingsItem({
    super.key,
    required this.label,
    required this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final String? subtitle;

  /// Optional widget shown between the text block and the chevron.
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Opacity(
          opacity: enabled ? 1 : 0.72,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AuraSpace.s12,
              horizontal: AuraSpace.s4,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AuraSurface.ink),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuraTextBlock(
                        label,
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        AuraTextBlock(
                          subtitle!.trim(),
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AuraSpace.s8),
                  trailing!,
                ],
                if (enabled)
                  const Padding(
                    padding: EdgeInsets.only(left: AuraSpace.s4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AuraSurface.muted,
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

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

enum MeStatusStyle { good, warn, neutral }

class MeStatusBadge extends StatelessWidget {
  const MeStatusBadge({
    super.key,
    required this.label,
    this.style = MeStatusStyle.neutral,
  });

  final String label;
  final MeStatusStyle style;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (style) {
      case MeStatusStyle.good:
        bg = AuraSurface.goodBg;
        fg = AuraSurface.goodInk;
      case MeStatusStyle.warn:
        bg = AuraSurface.warnBg;
        fg = AuraSurface.warnInk;
      case MeStatusStyle.neutral:
        bg = AuraSurface.elevated;
        fg = AuraSurface.muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// META CHIP
// ─────────────────────────────────────────────────────────────────────────────

class MeMetaChip extends StatelessWidget {
  const MeMetaChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: AuraTextBlock(
        label,
        style: AuraText.small.copyWith(
          fontWeight: FontWeight.w700,
          color: AuraSurface.muted,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// META LINK CHIP
// ─────────────────────────────────────────────────────────────────────────────

class MeMetaLinkChip extends StatelessWidget {
  const MeMetaLinkChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: MeMetaChip(label: label),
      ),
    );
  }
}
