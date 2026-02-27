import 'package:flutter/material.dart';
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

  static const double _leadingIconSize = 18;
  static const double _leadingTapSize = 36;

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
            vertical: AuraSpace.s10,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(_controller.value);
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: const _BrandMark(),
              );
            },
          ),
        ),
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
                  vertical: AuraSpace.s16,
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  // Original SVG colors
  static const Color _ringColor = Color(0xFFA0916E); // #A0916E
  static const Color _wordColor = Color(0xFF3C3C3C); // #3C3C3C

  // 10% smaller than 42px
  static const double _wordmarkSize = 38;

  // Keep ring intentional + proportional to wordmark
  static const double _ringSize = 44;
  static const double _ringStroke = 2.7;

  // Responsive fallback for narrow screens
  static const double _wordmarkSizeSmall = 29; // 32 -> ~29
  static const double _ringSizeSmall = 36; // 40 -> ~36
  static const double _ringStrokeSmall = 2.25; // 2.5 -> ~2.25

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final isTight = c.maxWidth.isFinite && c.maxWidth < 360;

        final fontSize = isTight ? _wordmarkSizeSmall : _wordmarkSize;
        final ringSize = isTight ? _ringSizeSmall : _ringSize;
        final stroke = isTight ? _ringStrokeSmall : _ringStroke;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _ringColor,
                    width: stroke,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Text(
              'AURA',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AuraText.title.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: _wordColor,
                // Keep it “masthead”, but not overly spaced
                letterSpacing: 1.4,
                height: 1.0,
              ),
            ),
          ],
        );
      },
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