import 'package:flutter/material.dart';

import 'aura_surface.dart';

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

  /// Kept for backward compatibility with existing screen calls.
  /// AuraScaffold no longer renders any header UI.
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

  static const double _defaultMaxWidth = 920;

  Widget _wrapBody(Widget child) {
    final width = maxWidth ?? _defaultMaxWidth;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    content = _wrapBody(content);

    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: SafeArea(
        child: content,
      ),
    );
  }
}