import 'package:flutter/material.dart';

import '../../../app/shell/shell_shared.dart';
import '../aura_scaffold.dart';
import '../aura_space.dart';
import '../aura_surface.dart';

/// Layout scaffold for the Investor surface.
///
/// Why this exists alongside `AuraPublicationLayout`
/// --------------------------------------------------
/// Publication surfaces (White Paper, Mission, Founder) use a single
/// 720 px reading column on a uniform page surface. That register reads
/// as editorial.
///
/// The Investor surface needs a different visual contract: section
/// bands at viewport-full width, each with its own background color
/// for strategic-pacing contrast, with content internally centered
/// at the same 1080 px chrome maximum used elsewhere in Aura. That
/// reads as executive presentation, not editorial.
///
/// Both layouts share Aura's typography, spacing, and color
/// systems — they diverge only in the band-vs-column composition.
class InvestorLayout extends StatelessWidget {
  const InvestorLayout({
    super.key,
    required this.title,
    required this.bands,
    this.actions,
    this.homePath = '/',
    this.showSiteFooter = true,
  });

  final String title;
  final List<Widget> bands;
  final List<Widget>? actions;
  final String homePath;
  final bool showSiteFooter;

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: title,
      actions: actions,
      homePath: homePath,
      // Effectively unconstrained so each [InvestorBand] can extend
      // edge-to-edge of the shell's content slot.
      maxWidth: double.infinity,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ...bands,
          if (showSiteFooter) const ShellFooter(),
        ],
      ),
    );
  }
}

/// Full-width band on the Investor surface.
///
/// Renders as a horizontal stripe across the shell's content slot
/// with a configurable background color, internally centered to the
/// canonical 1080 px content width with appropriate gutters.
///
/// Pass [surface] to vary section contrast (page → subtle → elevated)
/// and produce the strategic pacing the brief calls for.
class InvestorBand extends StatelessWidget {
  const InvestorBand({
    super.key,
    required this.child,
    this.surface = AuraSurface.page,
    this.topBorder = false,
    this.bottomBorder = false,
    this.maxWidth = 1080,
    this.verticalPadding = AuraSpace.xxl,
  });

  /// The section content. Internally constrained to [maxWidth].
  final Widget child;

  /// Band background color. Default keeps the canvas (page); pass
  /// [AuraSurface.subtle] for a contrasting band, [AuraSurface.card]
  /// for a hero-adjacent band, etc.
  final Color surface;

  /// Whether to draw a hairline divider at the top of the band.
  final bool topBorder;

  /// Whether to draw a hairline divider at the bottom of the band.
  final bool bottomBorder;

  /// Inner content maximum width. Keep at 1080 to align with Aura's
  /// shell chrome unless a band needs to feel deliberately tighter.
  final double maxWidth;

  /// Vertical padding inside the band. Bands carry their own breathing
  /// room because they live on the page rather than inside a single
  /// reading column.
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final horizontalPadding = isMobile ? AuraSpace.md : AuraSpace.xl;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: topBorder
              ? const BorderSide(color: AuraSurface.divider)
              : BorderSide.none,
          bottom: bottomBorder
              ? const BorderSide(color: AuraSurface.divider)
              : BorderSide.none,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
