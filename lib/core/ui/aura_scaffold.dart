import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

class AuraScaffold extends ConsumerWidget {
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
  static const double _headerHeight = 64;
  static const double _logoHeight = 28;
  static const String _logoAsset = 'assets/brand/AURA_logo_master.svg';

  bool _isPublicPath(String path) {
    if (path == '/' || path == '/public') return true;

    const publicPrefixes = <String>[
      '/mission',
      '/white-paper',
      '/founder',
      '/privacy',
      '/contact',
      '/account-deletion',
      '/investors',
      '/institutions',
      '/patrons',
      '/supporters',
      '/announcements',
      '/login',
      '/register',
      '/forgot-password',
      '/reset-password',
      '/verify-email',
      '/verify-pending',
      '/institution/sign-in',
    ];

    for (final prefix in publicPrefixes) {
      if (path == prefix || path.startsWith('$prefix/')) {
        return true;
      }
    }

    return false;
  }

  bool _canGoBack(BuildContext context) {
    return Navigator.of(context).canPop() || GoRouter.of(context).canPop();
  }

  void _goBackOrHome(BuildContext context) {
    if (_canGoBack(context)) {
      context.pop();
    } else {
      context.go(homePath);
    }
  }

  String _resolvedLogoRoute(AuthStatus authStatus) {
    return authStatus == AuthStatus.authed ? '/home' : '/public';
  }

  Widget _wrapInline(Widget child) {
    final width = maxWidth ?? _defaultMaxWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }

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

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;
    if (!_canGoBack(context)) return null;

    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        tooltip: 'Back',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: 36,
          height: 36,
        ),
        icon: const Icon(Icons.arrow_back, size: 18),
        onPressed: () => _goBackOrHome(context),
      ),
    );
  }

  Widget _buildLogo(BuildContext context, AuthStatus authStatus) {
    final target = _resolvedLogoRoute(authStatus);

    return Semantics(
      button: true,
      label: 'Aura',
      child: InkWell(
        onTap: () => context.go(target),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s4,
            vertical: AuraSpace.s4,
          ),
          child: SvgPicture.asset(
            _logoAsset,
            height: _logoHeight,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTitle() {
    final normalizedTitle = title.trim();

    if (normalizedTitle.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      normalizedTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: centerTitle ? TextAlign.center : TextAlign.start,
      style: AuraText.small.copyWith(
        fontWeight: FontWeight.w600,
        color: AuraSurface.ink,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final resolvedActions = <Widget>[
      ...(actions ?? const <Widget>[]),
      if (showHomeAction)
        TextButton(
          onPressed: () => context.go(homePath),
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

    if (resolvedActions.isEmpty) {
      return const SizedBox(width: 40);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < resolvedActions.length; i++) ...[
            if (i != 0) const SizedBox(width: AuraSpace.s8),
            resolvedActions[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStatusProvider);
    final path = GoRouterState.of(context).uri.path;
    final isPublic = _isPublicPath(path);
    final resolvedLeading = _buildLeading(context);

    Widget content = body;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    content = _wrapBody(content);

    final header = showHeader
        ? Container(
            height: _headerHeight,
            decoration: const BoxDecoration(
              color: AuraSurface.page,
              border: Border(
                bottom: BorderSide(color: AuraSurface.divider),
              ),
            ),
            child: _wrapInline(
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s16,
                  vertical: AuraSpace.s12,
                ),
                child: Row(
                  children: [
                    _buildLogo(context, authStatus),
                    const SizedBox(width: AuraSpace.s12),
                    Expanded(
                      child: Align(
                        alignment: centerTitle
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: resolvedLeading == null
                            ? _buildHeaderTitle()
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconTheme(
                                    data: const IconThemeData(
                                      color: AuraSurface.muted,
                                      size: 18,
                                    ),
                                    child: resolvedLeading,
                                  ),
                                  const SizedBox(width: AuraSpace.s8),
                                  Flexible(child: _buildHeaderTitle()),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s12),
                    _buildActions(context),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: SafeArea(
        top: true,
        bottom: !isPublic,
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
