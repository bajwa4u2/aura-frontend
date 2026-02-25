import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

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
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool showHomeAction;
  final String homePath;
  final bool showHeader;

  @override
  State<AuraScaffold> createState() => _AuraScaffoldState();
}

class _AuraScaffoldState extends State<AuraScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _defaultMaxWidth = 1040;

  // Brand sizing (fix: make logo visually prominent, not a dot)
  static const double _brandHeight = 34; // was 22
  static const double _brandMinWidth = 140;
  static const double _brandMaxWidth = 220;

  static const double _leadingIconSize = 18;
  static const double _leadingTapSize = 36;

  static const String _brandAsset = 'assets/brand/AURA_logo_master.svg';

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
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _brand(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Aura home',
      child: InkWell(
        onTap: () => context.go(widget.homePath),
        borderRadius: BorderRadius.circular(999),
        splashColor: AuraSurface.accentSoft,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s8, // slightly tighter than before
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(_controller.value);
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: _brandMinWidth,
                    maxWidth: _brandMaxWidth,
                  ),
                  child: SizedBox(
                    height: _brandHeight,
                    child: SvgPicture.asset(
                      _brandAsset,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      placeholderBuilder: (_) => _brandFallback(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _brandFallback() {
    return Text(
      'Aura',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AuraText.title.copyWith(
        fontSize: _brandHeight,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _actionsStrip(List<Widget> actions) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i != 0) const SizedBox(width: AuraSpace.s12),
            actions[i],
          ],
        ],
      ),
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (widget.leading != null) return widget.leading;
    if (!_canGoBack(context)) return null;

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
            foregroundColor: AuraSurface.muted,
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

    final header = widget.showHeader
        ? Container(
            decoration: const BoxDecoration(
              color: AuraSurface.page,
              border: Border(
                bottom: BorderSide(color: AuraSurface.divider),
              ),
            ),
            child: _wrapCentered(
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s16,
                  vertical: AuraSpace.s10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _brand(context),

                    if (resolvedLeading != null) ...[
                      const SizedBox(width: AuraSpace.s12),
                      IconTheme(
                        data: const IconThemeData(
                          color: AuraSurface.muted,
                          size: _leadingIconSize,
                        ),
                        child: resolvedLeading,
                      ),
                      const SizedBox(width: AuraSpace.s16),
                    ] else ...[
                      const SizedBox(width: AuraSpace.s12),
                    ],

                    Expanded(
                      child: showPageTitle
                          ? (widget.centerTitle
                              ? Center(child: _PageTitle(text: normalizedTitle))
                              : _PageTitle(text: normalizedTitle))
                          : const SizedBox.shrink(),
                    ),

                    if (headerActions.isNotEmpty) ...[
                      const SizedBox(width: AuraSpace.s16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _actionsStrip(headerActions),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

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
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AuraText.small.copyWith(
        fontWeight: FontWeight.w500,
        color: AuraSurface.ink,
      ),
    );
  }
}