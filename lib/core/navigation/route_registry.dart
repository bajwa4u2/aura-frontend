/// WHICH DESTINATIONS THIS APP ACTUALLY REGISTERS.
///
/// The return authority must be able to ask "is this a real destination?"
/// without carrying its own copy of the route table. A second list is a list
/// that drifts — the defect RC6 was written about, and the reason the
/// 2026-08-25 census was taken from the live router rather than from a scan of
/// `router.dart`.
///
/// So this is built FROM the router configuration at runtime. It answers about
/// PATTERNS, not literals: `/institution/aura-platform-llc/spaces` is a real
/// destination because `/institution/:institutionId/spaces` is registered.
library;

import 'package:go_router/go_router.dart';

class RouteRegistry {
  RouteRegistry(this._patterns);

  /// Build from a live route tree. Nested routes are resolved to full paths,
  /// exactly as `GoRouter` matches them.
  factory RouteRegistry.fromRoutes(List<RouteBase> routes) {
    final out = <RegExp>[];
    final seen = <String>{};

    void walk(List<RouteBase> rs, String prefix) {
      for (final r in rs) {
        var here = prefix;
        if (r is GoRoute) {
          here = r.path.startsWith('/')
              ? r.path
              : '${prefix.endsWith('/') ? prefix : '$prefix/'}${r.path}';
          // Only destinations that RENDER count. A redirect-only address is
          // not somewhere a person can be returned to — sending them there
          // would bounce them straight somewhere else, which is a return that
          // lies about where it went.
          if ((r.builder != null || r.pageBuilder != null) && seen.add(here)) {
            out.add(_patternOf(here));
          }
        }
        if (r.routes.isNotEmpty) walk(r.routes, here);
      }
    }

    walk(routes, '');
    return RouteRegistry(List.unmodifiable(out));
  }

  final List<RegExp> _patterns;

  static RegExp _patternOf(String path) {
    final escaped = path
        .split('/')
        .map((s) {
          if (s.isEmpty) return s;
          if (s.startsWith(':')) return '[^/]+';
          return RegExp.escape(s);
        })
        .join('/');
    return RegExp('^$escaped\$');
  }

  /// Does a concrete path name a destination this app renders?
  bool exists(String path) {
    var p = path.trim();
    final q = p.indexOf('?');
    if (q >= 0) p = p.substring(0, q);
    if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
    if (p.isEmpty) p = '/';
    for (final rx in _patterns) {
      if (rx.hasMatch(p)) return true;
    }
    return false;
  }

  int get length => _patterns.length;
}
