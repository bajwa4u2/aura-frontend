import 'package:flutter/material.dart';

import '../../../app/shell/shell_shared.dart';
import '../aura_scaffold.dart';
import '../aura_space.dart';
import '../aura_surface.dart';
import 'aura_publication_progress.dart';

/// Reusable layout for Aura's public long-form publications.
///
/// The publication system is intentionally distinct from
/// [DocumentScaffold] (which still owns legal/policy surfaces). Where
/// [DocumentScaffold] reads as a single shadowed "document card", the
/// publication layout reads as a flagship publication: a generous hero
/// at the top, a tight reading column on a calm surface, optional
/// sticky reading-progress, and the public site footer flowing as a
/// scroll-terminal.
///
/// The widget is deliberately small. Callers compose:
///
/// ```dart
/// AuraPublicationLayout(
///   title: 'White Paper',
///   hero: AuraPublicationHero(...),
///   readingColumnMaxWidth: 720,
///   showProgress: true,
///   children: [
///     AuraPublicationMarkdown(data: md),
///     AuraPublicationCallout(...),
///   ],
/// )
/// ```
///
/// Responsive contract:
///   * Hero spans the wide scaffold maxWidth (1080 by default).
///   * Reading column constrains to [readingColumnMaxWidth] (720 by
///     default — Aura's editorial line-length sweet spot).
///   * Mobile (`<600`) fills available width with consistent gutters.
///   * The site footer flows in-line as the last scroll element when
///     [showSiteFooter] is true.
class AuraPublicationLayout extends StatefulWidget {
  const AuraPublicationLayout({
    super.key,
    required this.title,
    required this.children,
    this.hero,
    this.actions,
    this.readingColumnMaxWidth = 720,
    this.heroMaxWidth = 1080,
    this.showSiteFooter = true,
    this.showProgress = false,
    this.homePath = '/',
  });

  /// AppBar title — also used as the document's accessible name.
  final String title;

  /// Trailing actions in the AppBar. Use sparingly; publication-grade
  /// surfaces prefer affordances in the hero rather than chrome.
  final List<Widget>? actions;

  /// Hero header rendered above the reading column. Pass an
  /// [AuraPublicationHero] (or any widget). Skipped if null.
  final Widget? hero;

  /// Reading-column children — typically a single
  /// [AuraPublicationMarkdown] or a sequence of section widgets.
  final List<Widget> children;

  /// Maximum width of the reading column.
  final double readingColumnMaxWidth;

  /// Maximum width of the hero band (and the scaffold's chrome).
  final double heroMaxWidth;

  /// Whether to render the public ShellFooter at the bottom of the
  /// scroll. Public-shell pages should leave this true.
  final bool showSiteFooter;

  /// Sticky thin progress bar at the top of the viewport, driven by
  /// the publication's ScrollController. Off by default — turn on
  /// only for long-form publications where progress communicates
  /// reading distance (e.g. the White Paper). Mission/founder pages
  /// generally don't need it.
  final bool showProgress;

  /// Path used by the AppBar home action. Defaults to `/`.
  final String homePath;

  @override
  State<AuraPublicationLayout> createState() => _AuraPublicationLayoutState();
}

class _AuraPublicationLayoutState extends State<AuraPublicationLayout> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final horizontalPadding = isMobile ? AuraSpace.md : AuraSpace.xl;
    final topPadding = widget.hero == null ? AuraSpace.lg : 0.0;

    return AuraScaffold(
      title: widget.title,
      actions: widget.actions,
      homePath: widget.homePath,
      maxWidth: widget.heroMaxWidth,
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            children: [
              if (widget.hero != null)
                _HeroWrap(
                  maxWidth: widget.heroMaxWidth,
                  horizontalPadding: horizontalPadding,
                  child: widget.hero!,
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  AuraSpace.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.readingColumnMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
                    ),
                  ),
                ),
              ),
              if (widget.showSiteFooter) const ShellFooter(),
            ],
          ),
          if (widget.showProgress)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AuraPublicationProgress(controller: _scrollController),
            ),
        ],
      ),
    );
  }
}

class _HeroWrap extends StatelessWidget {
  const _HeroWrap({
    required this.child,
    required this.maxWidth,
    required this.horizontalPadding,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: AuraSpace.xl,
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
