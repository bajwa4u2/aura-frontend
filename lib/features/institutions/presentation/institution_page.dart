import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
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

  /// Canonical institution content max width — sourced from the institution
  /// design system so every workspace screen shares the same column.
  static const double maxContentWidth = InsSpacing.contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final pad = padding ??
        const EdgeInsets.fromLTRB(
          InsSpacing.screenHPad,
          InsSpacing.screenVPad,
          InsSpacing.screenHPad,
          AuraSpace.s32,
        );

    final header = _PageHeader(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      showBack: showBack,
      onBack: onBack,
    );

    final children = <Widget>[
      header,
      const SizedBox(height: AuraSpace.s14),
      if (body != null) body!,
    ];

    final inner = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
            children: children,
          ),
        ),
      ),
    );

    return AuraScaffold(
      showHeader: false,
      body: scrollable ? SingleChildScrollView(child: inner) : inner,
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.showBack,
    required this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (!showBack) {
      return InsModeHeader(
        title: title,
        description: subtitle,
        primaryAction: trailing,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onBack ?? () => context.pop(),
          child: const Padding(
            padding: EdgeInsets.only(right: AuraSpace.s12, top: 4),
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
            description: subtitle,
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
