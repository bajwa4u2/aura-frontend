import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'aura_platform_components.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

/// The shared page surface — 104 routed screens compose it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// IT NOW RENDERS THE HEADER IT ALWAYS ACCEPTED
/// ─────────────────────────────────────────────────────────────────────────
///
/// Until 2026-08-25 this took `title`, `leading`, `actions`, `centerTitle` and
/// `showHomeAction` and drew NONE of them — its own comment said so. Eighteen
/// screens passed `leading:` believing they were providing a way back and got
/// nothing, which is the largest single reason the return-path census found 83
/// surfaces with no correct way out.
///
/// Founder ruling §1: grow the header rather than deleting the intent those
/// arguments express.
///
/// ─────────────────────────────────────────────────────────────────────────
/// IT DOES NOT DECIDE RETURN SEMANTICS
/// ─────────────────────────────────────────────────────────────────────────
///
/// Also founder ruling §1, and the reason there is no back arrow in here.
/// `ReturnPathAuthority` decides what returning means and `ReturnPathFrame`
/// presents it, once, above every routed surface. A second control in this
/// header would put two different answers on the same screen — which is the
/// state this chapter is removing, not a fix for it.
///
/// `leading` remains for the exceptional screen that owns a genuinely
/// different leading control. It is rendered as given and interpreted as
/// nothing.
class AuraScaffold extends StatelessWidget {
  AuraScaffold({
    super.key,
    this.title = '',
    Widget? body,
    Widget? child,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.maxWidth,
    this.padding,
    this.showHomeAction = false,
    this.homePath = '/',
    this.showHeader = true,
  })  : assert(
          body != null || child != null,
          'AuraScaffold requires either body: or child:',
        ),
        assert(
          body == null || child == null,
          'AuraScaffold: provide only one of body: or child:',
        ),
        body = body ?? child!;

  /// Page title. Rendered when non-empty and [showHeader] is set.
  final String title;
  final Widget body;

  /// Trailing page actions.
  final List<Widget>? actions;

  /// An exceptional leading control. NOT the return affordance — that is
  /// governed and presented by [ReturnPathFrame].
  final Widget? leading;
  final bool centerTitle;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  /// Offer an explicit route home. Distinct from returning: home is a
  /// destination, not a way out of this one.
  final bool showHomeAction;
  final String homePath;
  final bool showHeader;

  static const double _defaultMaxWidth = 920;

  bool get _hasHeader =>
      showHeader &&
      (title.trim().isNotEmpty ||
          leading != null ||
          showHomeAction ||
          (actions?.isNotEmpty ?? false));

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    if (_hasHeader) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: title,
            leading: leading,
            actions: actions,
            centerTitle: centerTitle,
            showHomeAction: showHomeAction,
            homePath: homePath,
          ),
          Expanded(child: content),
        ],
      );
    }

    // This app already renders screens inside AppShell/MemberShell/AdminShell.
    // Returning another Scaffold here can leave a blank grey content slot after
    // realtime route transitions because the nested scaffold owns its own body
    // surface while the shell is also swapping children. Keep AuraScaffold as a
    // pure page surface that always expands inside the shell content slot.
    return SizedBox.expand(
      child: AuraPageShell(
        maxWidth: maxWidth ?? _defaultMaxWidth,
        padding: EdgeInsets.zero,
        child: content,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.leading,
    required this.actions,
    required this.centerTitle,
    required this.showHomeAction,
    required this.homePath,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showHomeAction;
  final String homePath;

  @override
  Widget build(BuildContext context) {
    final label = title.trim();
    final titleWidget = label.isEmpty
        ? const SizedBox.shrink()
        : Text(
            label,
            style: AuraText.title,
            overflow: TextOverflow.ellipsis,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16, AuraSpace.s10, AuraSpace.s16, AuraSpace.s6),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AuraSpace.s10),
          ],
          Expanded(
            child: centerTitle ? Center(child: titleWidget) : titleWidget,
          ),
          if (showHomeAction)
            IconButton(
              tooltip: 'Home',
              icon: const Icon(Icons.home_outlined,
                  size: 20, color: AuraSurface.muted),
              onPressed: () => context.go(homePath),
            ),
          ...?actions,
        ],
      ),
    );
  }
}
