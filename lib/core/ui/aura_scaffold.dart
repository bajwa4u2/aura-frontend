import 'package:flutter/material.dart';

import 'aura_platform_components.dart';

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

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
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
