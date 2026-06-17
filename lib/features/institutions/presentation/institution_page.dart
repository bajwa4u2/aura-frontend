import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/surface/aura_discourse_surface.dart';
import '../ui/institution_ds.dart';

/// Standard institution-scoped page frame.
///
/// One canonical page chrome shared by every institution screen so layout
/// density, max width, page header, and empty/error states stay aligned
/// across messages / spaces / announcements / members / domains / profile /
/// edit / public preview.
class InstitutionPage extends StatelessWidget {
  const InstitutionPage({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.body,
    this.scrollable = true,
    this.padding,
    this.showBack = false,
    this.onBack,
    this.railModules,
  });

  /// Page title — rendered as the top-of-content headline. Required.
  final String title;

  /// Optional one-line subtitle under the title. Pass null to hide.
  final String? subtitle;

  /// Optional trailing action (e.g. a primary "Compose" button) shown at the
  /// right edge of the title row.
  final Widget? trailing;

  /// Page body. Either a scrollable list (when [scrollable] is true) or a
  /// fixed widget. When null an empty placeholder is rendered.
  final Widget? body;

  /// When true (default) the body is wrapped in a vertically scrollable
  /// `SingleChildScrollView`. Pass false for screens that own their own
  /// scrollable (e.g. paginated lists or `TabBarView`).
  final bool scrollable;

  /// Optional outer padding override. Defaults to the institution design-
  /// system page padding (`InsSpacing.screenHPad` / `screenVPad`).
  final EdgeInsetsGeometry? padding;

  /// Optional back arrow next to the title. Defaults to `context.pop()`.
  final bool showBack;
  final VoidCallback? onBack;

  /// Optional contextual rail modules. When non-empty the page composes
  /// as a discourse detail surface — a [kReadWidth] reading column
  /// beside an [AuraContextRail] (desktop) — instead of the standard
  /// centered institution column. Null/empty leaves every other
  /// institution screen's layout untouched.
  final List<Widget>? railModules;

  /// Canonical institution content max width — sourced from the institution
  /// design system so every workspace screen shares the same column.
  static const double maxContentWidth = InsSpacing.contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final pad =
        padding ??
        const EdgeInsets.fromLTRB(
          InsSpacing.screenHPad,
          InsSpacing.screenVPad,
          InsSpacing.screenHPad,
          AuraSpace.s32,
        );

    final header = _PageHeader(
      title: title,
      trailing: trailing,
      showBack: showBack,
      onBack: onBack,
    );

    final children = <Widget>[
      header,
      // Workspace-console pass — content begins immediately below the compact
      // command row. The descriptive subtitle was removed (operators don't
      // need a "what this page does" paragraph on every visit), so only a
      // small gap separates the command row from operational content.
      const SizedBox(height: AuraSpace.s8),
      if (body != null) body!,
    ];

    final columnContent = Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
        children: children,
      ),
    );

    // Discourse detail composition: a contextual rail beside the
    // reading column. AuraDiscourseSurface holds the reading column at
    // kReadWidth and drops the rail at laptop / mobile widths.
    final rail = railModules;
    if (rail != null && rail.isNotEmpty) {
      final reading = scrollable
          ? SingleChildScrollView(child: columnContent)
          : columnContent;
      return AuraScaffold(
        showHeader: false,
        maxWidth: kWorkspaceWidth,
        body: AuraDiscourseSurface(reading: reading, railModules: rail),
      );
    }

    // Scrollable pages use a ListView — like InsScreen — which top-anchors its
    // content. Short bodies (Members, Join Requests, Invites, Spaces, empty
    // states) sit directly under the command row instead of floating in the
    // vertical middle of the surface. The surface scaffold vertically centers
    // its center column, which is why a SingleChildScrollView + Align here
    // still floated; a ListView starts at the top regardless.
    if (scrollable) {
      return AuraScaffold(
        showHeader: false,
        maxWidth: maxContentWidth,
        body: ListView(
          padding: pad,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Non-scrollable pages own their own scroll/layout; top-align the fixed
    // content so it begins at the top of the surface.
    return AuraScaffold(
      showHeader: false,
      maxWidth: maxContentWidth,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: columnContent,
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.trailing,
    required this.showBack,
    required this.onBack,
  });

  final String title;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // Workspace doctrine: the page header is a compact command row (context +
    // primary action). Descriptive subtitles are intentionally NOT rendered in
    // the institution workspace — that copy belongs in onboarding/help, not in
    // daily operator workflows. `subtitle` is retained on the API for callers
    // but no longer painted here.
    if (!showBack) {
      return InsModeHeader(
        title: title,
        primaryAction: trailing,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onBack ?? () => context.pop(),
          child: const Padding(
            padding: EdgeInsets.only(right: AuraSpace.s12),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AuraSurface.muted,
            ),
          ),
        ),
        Expanded(
          child: InsModeHeader(
            title: title,
            primaryAction: trailing,
          ),
        ),
      ],
    );
  }
}

/// Standard institution-scoped empty state used across institution screens.
/// Wraps [AuraEmptyState] with the same horizontal padding the page body
/// uses so empty states sit at the same x-axis as content.
class InstitutionEmptyState extends StatelessWidget {
  const InstitutionEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s24),
      child: AuraEmptyState(
        icon: icon,
        title: title,
        body: body,
        action: action,
      ),
    );
  }
}
