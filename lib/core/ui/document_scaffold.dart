import 'package:flutter/material.dart';

import 'aura_design_system.dart';
import 'aura_platform_components.dart';
import 'aura_scaffold.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

/// Standard frame for document-like pages (Mission, Privacy, Founder, Hubs).
///
/// Rules:
/// - Always centered and constrained
/// - Always uses AuraScaffold
/// - Always scrolls
/// - Reading-first atmosphere
class DocumentScaffold extends StatelessWidget {
  const DocumentScaffold({
    super.key,
    required this.title,
    required this.child,
    this.maxWidth = 780,
    this.actions,
    this.footer,
    this.homePath = '/',
  });

  final String title;
  final Widget child;
  final double maxWidth;
  final List<Widget>? actions;
  final Widget? footer;
  final String homePath;

  @override
  Widget build(BuildContext context) {
    final heroSubtitle = _heroSubtitle(title);

    return AuraScaffold(
      title: title,
      actions: actions,
      homePath: homePath,
      maxWidth: maxWidth + 240,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.md,
          AuraSpace.lg,
          AuraSpace.md,
          AuraSpace.xl,
        ),
        children: [
          AuraGradientHero(
            badge: 'Public platform',
            title: title,
            subtitle: heroSubtitle,
            actions: const [
              AuraTrustBadge(label: 'Trusted record'),
              AuraTrustBadge(label: 'Institution ready', icon: Icons.apartment_outlined),
            ],
            metrics: const [
              AuraMetricCard(
                label: 'Communication',
                value: 'Identity-bound',
              ),
              AuraMetricCard(
                label: 'Publishing',
                value: 'Chronological',
              ),
              AuraMetricCard(
                label: 'Governance',
                value: 'Visible',
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.lg),
          _DocumentSurface(child: child),
          if (footer != null) ...[
            const SizedBox(height: AuraSpace.lg),
            _DocumentSurface(child: footer!),
          ],
        ],
      ),
    );
  }

  String _heroSubtitle(String title) {
    final lowered = title.toLowerCase();
    if (lowered.contains('mission')) {
      return 'The operating principles behind Aura\'s civic communication layer.';
    }
    if (lowered.contains('white')) {
      return 'Architecture, governance, and product intent in one readable surface.';
    }
    if (lowered.contains('investor')) {
      return 'A trusted platform with institutional durability and governed growth.';
    }
    if (lowered.contains('contact')) {
      return 'Reach the team through a calm, accountable support surface.';
    }
    if (lowered.contains('institution')) {
      return 'Institutional voice, verified identity, and public continuity.';
    }
    if (lowered.contains('privacy')) {
      return 'Privacy, terms, and deletion with the same seriousness as the product.';
    }
    return 'A premium reading surface for Aura\'s public platform materials.';
  }
}

class _DocumentSurface extends StatelessWidget {
  const _DocumentSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: BoxDecoration(
        gradient: AuraGradients.card,
        color: AuraSurface.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AuraSurface.divider,
          width: 1,
        ),
        boxShadow: AuraShadows.panel,
      ),
      child: child,
    );
  }
}

/// Small helpers for document pages (consistent editorial rhythm).
class Doc {
  Doc._();

  static Widget title(String text) => Text(
        text,
        style: AuraText.title.copyWith(fontSize: 30),
      );

  static Widget meta(String text) => Text(
        text,
        style: AuraText.muted.copyWith(fontWeight: FontWeight.w600),
      );

  static Widget lede(String text) => Padding(
        padding: const EdgeInsets.only(top: AuraSpace.sm),
        child: Text(
          text,
          style: AuraText.body.copyWith(
            fontSize: 16,
            height: 1.8,
          ),
        ),
      );

  static Widget h(String text) => Padding(
        padding: const EdgeInsets.only(
          top: AuraSpace.xl,
          bottom: AuraSpace.sm,
        ),
        child: Text(
          text,
          style: AuraText.emphasis.copyWith(fontSize: 16),
        ),
      );

  static Widget p(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AuraSpace.sm),
        child: Text(
          text,
          style: AuraText.body.copyWith(height: 1.72),
        ),
      );

  static Widget callout(String text) => Container(
        margin: const EdgeInsets.symmetric(vertical: AuraSpace.md),
        padding: const EdgeInsets.all(AuraSpace.md),
        decoration: BoxDecoration(
          gradient: AuraGradients.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Text(
          text,
          style: AuraText.body.copyWith(height: 1.6),
        ),
      );

  static Widget bullets(List<String> items) => Padding(
        padding: const EdgeInsets.only(bottom: AuraSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (x) => Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 9),
                        child: Icon(
                          Icons.arrow_right_rounded,
                          size: 16,
                          color: AuraSurface.accent,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.sm),
                      Expanded(
                        child: Text(
                          x,
                          style: AuraText.body.copyWith(height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
}
