/// THE ONE PLACE A RETURN AFFORDANCE IS PRESENTED.
///
/// Founder ruling 2026-08-25 §2 and §10: return SEMANTICS come from
/// [ReturnPathAuthority]; shared chrome RENDERS that decision; a screen supplies
/// its content and only exceptional screen-specific behaviour. Correct the
/// shared layer, not 83 screens.
///
/// This frames the routed child inside `AppShell` — the single widget that
/// sees every routed surface and already resolves the path. 139 destinations
/// need an affordance; 96 of them compose `AuraScaffold` and 43 do not, so a
/// page-level home would have reached most of the product and quietly missed a
/// third of it.
///
/// WHAT IT DELIBERATELY DOES NOT DO
///
///  * It does not frame Meetings/Live. Founder ruling §13 protects them, and
///    an affordance appearing above a live room WOULD be a modification.
///  * It does not frame the auth/boot gates. RC4 owns those exits, and a
///    hierarchical Back on a sign-in gate contradicts a governed transition.
///  * It does not reduce every semantic to a back arrow. Cancel is not Back;
///    Close is not Back. The ruling is explicit and so is the presentation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'return_path_authority.dart';
import 'route_registry.dart';

/// Lets an exceptional screen say "I present my own way out."
///
/// Not an escape hatch for convenience: it exists because a few surfaces own a
/// genuinely different exit (a live room's leave, a guest flow's own shell),
/// and two controls that do different things are worse than one.
class ReturnAffordanceScope extends InheritedWidget {
  const ReturnAffordanceScope({
    super.key,
    required this.suppressed,
    required super.child,
  });

  final bool suppressed;

  static bool isSuppressed(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ReturnAffordanceScope>()
          ?.suppressed ??
      false;

  @override
  bool updateShouldNotify(ReturnAffordanceScope old) =>
      old.suppressed != suppressed;
}

/// Frames a routed surface with the governed return affordance.
class ReturnPathFrame extends ConsumerStatefulWidget {
  const ReturnPathFrame({
    super.key,
    required this.path,
    required this.child,
  });

  /// The path the SHELL resolved. Kept because the shell already computes it,
  /// but the LIVE location below is what the affordance is built from.
  final String path;
  final Widget child;

  @override
  ConsumerState<ReturnPathFrame> createState() => _ReturnPathFrameState();
}

class _ReturnPathFrameState extends ConsumerState<ReturnPathFrame> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (identical(router, _router)) return;
    _router?.routeInformationProvider.removeListener(_onRouteChanged);
    _router = router;
    router.routeInformationProvider.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _router?.routeInformationProvider.removeListener(_onRouteChanged);
    super.dispose();
  }

  /// A SHELL-INTERNAL PUSH DOES NOT REBUILD THE SHELL.
  ///
  /// Found on a physical Pixel, 2026-08-25, by the one test only a handset can
  /// run: Android system back returned to the real predecessor while the
  /// visible control sent the person to the public root. Two mechanisms
  /// disagreeing means one of them is lying about where the person is.
  ///
  /// Pushing a destination inside the SAME shell adds a page to the shell's
  /// navigator without re-invoking the shell's builder, so this frame kept the
  /// previous destination's answer. Listening to the route information
  /// provider fixes the location — but `canPop` is STILL false at that instant
  /// and only becomes true a frame later, once the delegate's match list has
  /// settled. Measured, both times.
  ///
  /// So: rebuild on the notification, and again after the frame.
  void _onRouteChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final store = ref.watch(tokenStoreProvider);
    final isAuthed =
        store.isLoaded && (store.accessToken?.trim().isNotEmpty ?? false);

    final location = router.routeInformationProvider.value.uri.path;
    if (ReturnPathAuthority.isProtectedDomain(location)) return widget.child;

    final registry = RouteRegistry.fromRoutes(router.configuration.routes);
    final action = ReturnPathAuthority.resolve(
      path: location,
      // The router's own answer about whether a predecessor exists — the whole
      // of the entry-mode distinction, asked and never guessed.
      canPop: router.canPop(),
      isAuthed: isAuthed,
      exists: registry.exists,
    );

    if (!action.hasAffordance) return widget.child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReturnBar(action: action, isAuthed: isAuthed),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _ReturnBar extends StatelessWidget {
  const _ReturnBar({required this.action, required this.isAuthed});

  /// What was true when this was drawn. Used for the LABEL.
  final ReturnAction action;
  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    // A screen that owns its own exit takes precedence — one control, not two.
    if (ReturnAffordanceScope.isSuppressed(context)) {
      return const SizedBox.shrink();
    }

    final hierarchical = action.isHierarchical;
    final icon = hierarchical
        ? Icons.arrow_back_rounded
        : Icons.close_rounded;
    // Naming the destination when it is known is the difference between "back"
    // and "back TO WHAT" — and the hardcoded-parent defect this replaces was
    // readable precisely because it named where it went.
    final label = hierarchical
        ? (action.label == null ? 'Back' : 'Back to ${action.label}')
        : 'Cancel';

    return Semantics(
      button: true,
      label: label,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AuraSpace.s10, AuraSpace.s8, AuraSpace.s10, 0),
          child: InkWell(
            // The key sits on the TAPPABLE, not on the Semantics wrapper: the
            // wrapper spans the full width, so a tap at its centre lands in
            // empty space beside the control. The certification test found
            // exactly that — the control rendered, the tap missed, and it
            // looked like the return did nothing.
            key: returnAffordanceKey,
            // Re-resolved at TAP time, never from what was drawn. The
            // label can lag a frame behind `canPop`; the ACTION must not,
            // because that is the difference between unwinding one step and
            // being sent to the root.
            onTap: () => performReturn(context, _live(context, isAuthed) ?? action),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s6, vertical: AuraSpace.s6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: AuraSurface.muted),
                  const SizedBox(width: AuraSpace.s6),
                  Text(
                    label,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolve the return action from the router AS IT IS NOW.
ReturnAction? _live(BuildContext context, bool isAuthed) {
  final router = GoRouter.of(context);
  return ReturnPathAuthority.resolve(
    path: router.routeInformationProvider.value.uri.path,
    canPop: router.canPop(),
    isAuthed: isAuthed,
    exists: RouteRegistry.fromRoutes(router.configuration.routes).exists,
  );
}

/// The governed return control. One per routed surface, by construction.
const Key returnAffordanceKey = ValueKey('aura.return.affordance');

/// Carry out a governed return.
///
/// Separate from presentation so that a system Back, a gesture, a keyboard
/// shortcut and the visible control all converge on ONE implementation — the
/// founder's §4 requirement that these not drift apart.
void performReturn(BuildContext context, ReturnAction action) {
  switch (action.semantic) {
    case ReturnSemantic.rootNoReturn:
      return;
    case ReturnSemantic.stackReturn:
    case ReturnSemantic.modalDismiss:
      if (GoRouter.of(context).canPop()) GoRouter.of(context).pop();
      return;
    case ReturnSemantic.flowCancel:
      if (action.destination == null) {
        if (GoRouter.of(context).canPop()) GoRouter.of(context).pop();
        return;
      }
      break;
    case ReturnSemantic.parentReturn:
    case ReturnSemantic.contextReturn:
    case ReturnSemantic.deepLinkFallback:
    case ReturnSemantic.flowComplete:
    case ReturnSemantic.terminalExit:
      break;
  }
  final target = ReturnPathAuthority.safeDestination(action.destination);
  if (target == null) return;
  // `go`, not `push`: returning moves UP. Pushing a parent onto the stack
  // would grow history in the wrong direction and make the next Back go
  // deeper — the loop this chapter is removing.
  GoRouter.of(context).go(target);
}
