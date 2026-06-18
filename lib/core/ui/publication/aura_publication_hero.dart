import 'package:flutter/material.dart';

import '../aura_radius.dart';
import '../aura_space.dart';
import '../aura_surface.dart';
import '../aura_text.dart';

/// Hero header for an Aura publication.
///
/// Renders an eyebrow ("WHITE PAPER", "MISSION", "FOUNDER") + a large
/// title + an optional subtitle, then a meta strip (version,
/// updated-date, reading-time) and a trailing action row (download,
/// back to publications, etc.).
///
/// The eyebrow + uppercase letter-spacing is the key signal that the
/// document is a "published artifact" rather than a documentation
/// page. The publication system uses this consistently across White
/// Paper, Mission, Founder, Supporters, and Patrons so the surfaces
/// feel like one ecosystem.
class AuraPublicationHero extends StatelessWidget {
  const AuraPublicationHero({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.publisher = 'Aura Platform LLC',
    this.metaItems = const <AuraPublicationMetaItem>[],
    this.actions = const <Widget>[],
  });

  /// Eyebrow label, rendered uppercase with wide letter-spacing.
  /// Examples: "White Paper", "Mission", "Founder", "Supporters".
  final String eyebrow;

  /// Display title — short, declarative, capital case. Examples:
  ///   "Institution operating infrastructure."
  ///   "Mission."
  final String title;

  /// Optional one-paragraph subtitle below the title. Use for a
  /// publication's thesis statement. Avoid more than two sentences.
  final String? subtitle;

  /// Publisher line rendered above the eyebrow. Default
  /// "Aura Platform LLC" — the locked institutional positioning.
  final String publisher;

  /// Meta strip below the title: version, updated date, reading
  /// time. Hidden if empty.
  final List<AuraPublicationMetaItem> metaItems;

  /// Action affordances rendered as a Wrap below the meta strip.
  /// Typically the PDF download + a back-to-publications navigation
  /// button. Hidden if empty.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final headlineStyle = isMobile
        ? AuraText.headline.copyWith(fontSize: 28, height: 1.18)
        : AuraText.display.copyWith(fontSize: 40, height: 1.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Publisher line — small, uppercase, gold-accent so the
        // institutional ownership is visible at a glance.
        Text(
          publisher.toUpperCase(),
          style: AuraText.micro.copyWith(
            color: const Color(0xFFC9A55C),
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AuraSpace.s6),

        // Eyebrow label.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.elevated,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Text(
            eyebrow.toUpperCase(),
            style: AuraText.label.copyWith(
              color: AuraSurface.ink,
              letterSpacing: 1.2,
            ),
          ),
        ),

        const SizedBox(height: AuraSpace.md),

        // Title.
        Text(title, style: headlineStyle),

        if ((subtitle ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.md),
          Text(
            subtitle!,
            style: AuraText.body.copyWith(
              fontSize: isMobile ? 16 : 18,
              height: 1.65,
              color: AuraSurface.ink,
            ),
          ),
        ],

        if (metaItems.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.lg),
          _MetaStrip(items: metaItems),
        ],

        if (actions.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.lg),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: actions,
          ),
        ],
      ],
    );
  }
}

class _MetaStrip extends StatelessWidget {
  const _MetaStrip({required this.items});

  final List<AuraPublicationMetaItem> items;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(_MetaItemView(item: items[i]));
      if (i < items.length - 1) {
        children.add(const _MetaSeparator());
      }
    }
    return Wrap(
      spacing: AuraSpace.s12,
      runSpacing: AuraSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _MetaItemView extends StatelessWidget {
  const _MetaItemView({required this.item});

  final AuraPublicationMetaItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 14, color: AuraSurface.muted),
        const SizedBox(width: 6),
        Text(
          item.label,
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetaSeparator extends StatelessWidget {
  const _MetaSeparator();
  @override
  Widget build(BuildContext context) => Text(
        '·',
        style: AuraText.small.copyWith(color: AuraSurface.faint),
      );
}

/// One row in the publication's meta strip.
class AuraPublicationMetaItem {
  const AuraPublicationMetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
