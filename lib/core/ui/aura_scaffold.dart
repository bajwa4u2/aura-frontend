import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'aura_space.dart';
import 'aura_platform_components.dart';
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

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: AuraPageShell(
        maxWidth: maxWidth ?? _defaultMaxWidth,
        padding: EdgeInsets.zero,
        child: showHeader && title.trim().isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AuraSpace.md,
                      AuraSpace.lg,
                      AuraSpace.md,
                      AuraSpace.sm,
                    ),
                    child: AuraGradientHeader(
                      title: title,
                      subtitle: _subtitleForTitle(title),
                      trailing: showHomeAction
                          ? IconButton(
                              onPressed: () => context.go(homePath),
                              icon: const Icon(Icons.home_outlined),
                              tooltip: 'Home',
                            )
                          : null,
                    ),
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
    );
  }

  String? _subtitleForTitle(String value) {
    final title = value.trim().toLowerCase();
    if (title.isEmpty) return null;
    if (title.contains('message') || title.contains('conversation')) {
      return 'A premium communication surface for Aura.';
    }
    if (title.contains('profile') || title.contains('presence') || title.contains('me')) {
      return 'Trusted identity and public record.';
    }
    if (title.contains('institution')) {
      return 'Institutional voice, governance, and continuity.';
    }
    if (title.contains('announcement')) {
      return 'Official communication and publication.';
    }
    if (title.contains('realtime') || title.contains('live')) {
      return 'Live collaboration and call control.';
    }
    if (title.contains('auth') || title.contains('login') || title.contains('register')) {
      return 'Secure access and onboarding.';
    }
    if (title.contains('saved') || title.contains('updates') || title.contains('activity')) {
      return 'A quiet signal center.';
    }
    return null;
  }
}
