import 'aura_responsive.dart';
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

  /// Pass this as [maxWidth] when the CHILD resolves its own composition.
  ///
  /// A surface built from `AuraSurfaceScaffold` already decides how wide its
  /// work column is, where its rails sit and what the gutters are. Wrapping
  /// that in this scaffold's own 920 px cap made a third independent width
  /// authority above the other two: on a 2011 px Windows window the whole
  /// composition -- feed AND contextual rail together -- was squeezed into
  /// 920 px in the middle of the screen, which is the ~665 px empty band the
  /// founder saw to the left of the work.
  ///
  /// Named rather than passing `double.infinity` at the call site, so the
  /// intent is legible: this is not "as wide as possible", it is "not mine to
  /// decide".
  static const double childDecidesWidth = double.infinity;

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
      // THE DEFAULT IS A MEASURE, NOT A NUMBER.
      //
      // `_defaultMaxWidth` was a flat 920 px applied to every screen that did
      // not name a width. On a 2000 px Windows window that left Discover as a
      // ~900 px column with 500 px of empty page either side — a browser
      // column inside a native frame, which is the thing this whole pass
      // exists to end.
      //
      // `AuraMeasure.feed` grows with the room and still stops well short of
      // an unreadable line, so screens that were built expecting a calm
      // column stay calm; they simply stop refusing the window. A caller that
      // genuinely needs a fixed width still passes one.
      child: LayoutBuilder(
        builder: (context, constraints) {
          // IT ONLY EVER WIDENS.
          //
          // The first attempt resolved the measure outright, which SUBTRACTS
          // a gutter — so on a narrow surface the page became 32 px narrower
          // than before and a Row on the auth screen that had just fitted
          // overflowed by 99 px. Three navigation contract tests caught it.
          //
          // Mobile behaviour must not move for a desktop correction. Taking
          // the larger of the old cap and the measured width means narrow
          // windows are byte-for-byte unchanged, and only rooms bigger than
          // the old 920 px see any difference.
          final grown = constraints.maxWidth.isFinite
              ? auraMeasureWidth(AuraMeasure.feed, constraints.maxWidth)
              : _defaultMaxWidth;
          final resolved = maxWidth ??
              (grown > _defaultMaxWidth ? grown : _defaultMaxWidth);
          return AuraPageShell(
            maxWidth: resolved,
            padding: EdgeInsets.zero,
            child: content,
          );
        },
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
