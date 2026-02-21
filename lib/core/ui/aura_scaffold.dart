import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

/// Aura's base scaffold.
///
/// Structural rules:
/// - Aura identity is owned here (global header).
/// - Identity comes first: logo/mark is always the leftmost element.
/// - Header + body share the same centered grid.
/// - Screens control content only; scaffold controls placement + posture.
///
/// Brand hierarchy rule (locked):
/// - Logo must feel primary.
/// - Back arrow + page title must never visually overpower the logo.
/// - Right-side actions stay in the header rail (outside reading block).
class AuraScaffold extends StatefulWidget {
  const AuraScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.maxWidth,
    this.padding,
    this.showHomeAction = false,
    this.homePath = '/public',
    this.showHeader = true,
  });

  final String title;
  final Widget body;

  /// Right-side header actions (in addition to optional Home).
  final List<Widget>? actions;

  /// Leading widget. If null, scaffold shows Back when possible.
  final Widget? leading;

  final bool centerTitle;

  /// Constrains header + body to this width and centers it.
  final double? maxWidth;

  /// Optional padding wrapper for the body.
  final EdgeInsetsGeometry? padding;

  /// If true, show a single Home action.
  final bool showHomeAction;

  /// Home target. `/public` is safe for authed users (router redirects to /home).
  final String homePath;

  /// Rare escape hatch, but sometimes useful.
  final bool showHeader;

  @override
  State<AuraScaffold> createState() => _AuraScaffoldState();
}

class _AuraScaffoldState extends State<AuraScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _defaultMaxWidth = 980;

  // Brand hierarchy tuning (global)
  static const double _logoHeight = 24;// tuned for wide wordmark
  static const double _leadingIconSize = 18; // smaller so it never dominates
  static const double _leadingTapSize = 36; // comfortable but not loud

  bool _canGoBack(BuildContext context) {
    return Navigator.of(context).canPop() || GoRouter.of(context).canPop();
  }

  void _goBackOrHome(BuildContext context) {
    if (_canGoBack(context)) {
      context.pop();
    } else {
      context.go(widget.homePath);
    }
  }

  Widget _wrapCentered(Widget child) {
    final width = widget.maxWidth ?? _defaultMaxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _brand(BuildContext context) {
    // Brand identity (primary, always leftmost).
    // We intentionally avoid asset-based wordmarks here so the frontend can run
    // in any environment without missing-asset failures.
    return Semantics(
      button: true,
      label: 'Aura home',
      child: InkWell(
        onTap: () => context.go(widget.homePath),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8,
            vertical: AuraSpace.s8,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(_controller.value);
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Text(
                  'Aura',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.title.copyWith(
                    fontSize: _logoHeight,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _actionsStrip(List<Widget> actions) {
    if (actions.isEmpty) return const SizedBox.shrink();

    // No Wrap. If it doesn't fit, it scrolls horizontally.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i != 0) const SizedBox(width: AuraSpace.s8),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildLeading(BuildContext context) {
    // If screen provided a leading, keep it — but we will visually quiet it via IconTheme.
    if (widget.leading != null) return widget.leading;

    if (!_canGoBack(context)) return null;

    // Default leading (quiet + smaller than brand)
    return SizedBox(
      width: _leadingTapSize,
      height: _leadingTapSize,
      child: IconButton(
        tooltip: 'Back',
        iconSize: _leadingIconSize,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: _leadingTapSize,
          height: _leadingTapSize,
        ),
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _goBackOrHome(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLeading = _buildLeading(context);

    final normalizedTitle = widget.title.trim();
    final showPageTitle =
        normalizedTitle.isNotEmpty && normalizedTitle.toLowerCase() != 'aura';

    final headerActions = <Widget>[
      ...(widget.actions ?? const <Widget>[]),
      if (widget.showHomeAction)
        TextButton(
          onPressed: () => context.go(widget.homePath),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s12,
              vertical: AuraSpace.s8,
            ),
            foregroundColor: AuraText.muted.color,
            textStyle: AuraText.small,
          ),
          child: const Text('Home'),
        ),
    ];

    Widget content = widget.body;
    if (widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }
    content = _wrapCentered(content);

    Widget header = const SizedBox.shrink();

    if (widget.showHeader) {
      header = Container(
        color: AuraSurface.page,
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s10),
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AuraSurface.divider)),
          ),
          child: _wrapCentered(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ Identity first, always leftmost.
                  _brand(context),

                  // Back / leading comes AFTER identity, and stays visually secondary.
                  if (resolvedLeading != null) ...[
                    const SizedBox(width: AuraSpace.s6),
                    IconTheme(
                      data: IconThemeData(
                        color: AuraText.muted.color,
                        size: _leadingIconSize,
                      ),
                      child: resolvedLeading,
                    ),
                    const SizedBox(width: AuraSpace.s10),
                  ] else ...[
                    const SizedBox(width: AuraSpace.s12),
                  ],

                  // Page title must never dominate the brand.
                  if (showPageTitle) ...[
                    Expanded(
                      child: widget.centerTitle
                          ? Center(child: _PageTitle(text: normalizedTitle))
                          : _PageTitle(text: normalizedTitle),
                    ),
                  ] else ...[
                    const Spacer(),
                  ],

                  // Right rail (outside reading block)
                  if (headerActions.isNotEmpty) ...[
                    const SizedBox(width: AuraSpace.s10),
                    Flexible(child: _actionsStrip(headerActions)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    // Smaller + lighter than before so it never competes with the logo.
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AuraText.small.copyWith(
        fontWeight: FontWeight.w500,
        color: AuraText.body.color,
      ),
    );
  }
}
