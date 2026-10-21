import 'package:flutter/widgets.dart';

import 'navigation_authority.dart';

/// THE ORIGIN TAB (founder decision 2026-10-21, supersedes the 2026-08-16
/// "truthful no-selection" rule for detail routes).
///
/// A detail page — a post, an announcement, an article, a thread, a
/// conversation, a profile, an institution, a space, a meeting, a settings
/// page — keeps highlighted the primary destination it was opened FROM. That
/// is the convention on every platform Aura ships on: an iOS tab bar always
/// shows the tab whose stack you are in, Material bottom navigation always has
/// one active destination, and a desktop rail keeps its section marked while
/// you are in that section's depth. "Nothing selected" left people without a
/// "you are here", and made tapping the tab you came from do nothing useful.
///
/// The origin is the last primary destination a person was actually on.
/// Create is never an origin: it is an action, and what it makes belongs to
/// the place it was published to. When there is no origin (a cold start from a
/// notification, a shared link or a universal link) the content's own home
/// answers — see [NavigationAuthority.contentHomeOf].
class NavigationOrigin {
  NavigationOrigin._();

  static PrimaryDestination? _last;

  /// The destination to highlight for [path], recording it as the origin when
  /// [path] is itself a primary destination.
  static PrimaryDestination? selectedFor(String path) {
    final primary = NavigationAuthority.primaryOf(path);
    if (primary != null) {
      if (primary != PrimaryDestination.create) _last = primary;
      return primary;
    }
    return _last ?? NavigationAuthority.contentHomeOf(path);
  }

  /// The remembered origin, for tests and diagnostics.
  static PrimaryDestination? get last => _last;

  @visibleForTesting
  static void reset() => _last = null;
}

/// Tapping the tab you are already on, at its root, returns the page to its
/// top — the standard re-select behaviour on iOS, Android, desktop and web.
/// A shell's navigation calls [PrimaryReselect.signal]; the page area listens
/// through [ScrollToTopOnReselect].
class PrimaryReselect {
  PrimaryReselect._();

  static final ValueNotifier<int> _ticks = ValueNotifier<int>(0);

  static void signal() => _ticks.value++;
}

/// Wraps a shell's routed page area and scrolls it to the top whenever the
/// current tab is re-selected at its root.
class ScrollToTopOnReselect extends StatefulWidget {
  const ScrollToTopOnReselect({super.key, required this.child});

  final Widget child;

  @override
  State<ScrollToTopOnReselect> createState() => _ScrollToTopOnReselectState();
}

class _ScrollToTopOnReselectState extends State<ScrollToTopOnReselect> {
  @override
  void initState() {
    super.initState();
    PrimaryReselect._ticks.addListener(_onReselect);
  }

  @override
  void dispose() {
    PrimaryReselect._ticks.removeListener(_onReselect);
    super.dispose();
  }

  void _onReselect() {
    if (mounted) scrollPrimaryToTop(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The shell does not know which scroll view a page owns, so this scrolls the
/// first vertical one inside [bodyContext] that is not already at the top.
void scrollPrimaryToTop(BuildContext? bodyContext) {
  if (bodyContext == null) return;
  ScrollableState? found;
  void visit(Element element) {
    if (found != null) return;
    if (element is StatefulElement && element.state is ScrollableState) {
      final state = element.state as ScrollableState;
      final position = state.position;
      if (axisDirectionToAxis(state.axisDirection) == Axis.vertical &&
          position.hasPixels &&
          position.pixels > position.minScrollExtent) {
        found = state;
        return;
      }
    }
    element.visitChildElements(visit);
  }

  (bodyContext as Element).visitChildElements(visit);
  final target = found;
  if (target == null) return;
  target.position.animateTo(
    target.position.minScrollExtent,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );
}
