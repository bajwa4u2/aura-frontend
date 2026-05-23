import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'route_classification.dart';
import '../core/auth/auth_providers.dart';
import '../core/diagnostics/runtime_trace.dart';
import 'shell/admin_shell.dart';
import 'shell/member_shell.dart';
import 'shell/public_shell.dart';

export 'shell/admin_shell.dart' show AdminShell;
export 'shell/member_shell.dart' show MemberShell, InstitutionShell;
export 'shell/public_shell.dart' show PublicShell;

/// Context-based shell selection (not route-based).
///
/// Rule (single source of truth):
///
///   1. If the path is administrative (`/admin*`)            → AdminShell.
///   2. Else if the path is institution-shell                → InstitutionShell.
///       (any `/institution/...` path)
///   3. Else if the user is authenticated                    → MemberShell.
///       (covers public content like `/u/:handle`,
///        `/posts/:id`, `/institutions/:slug`,
///        `/announcements/...`, `/search`, `/direct/:id` —
///        the previous "force PublicShell when authed" rule
///        is gone.)
///   4. Else (unauthenticated)                               → PublicShell.
///
/// Anything else — including the bootstrap state — renders the PublicShell
/// briefly while auth resolves; once authStatus settles to `authed` the next
/// rebuild flips to MemberShell automatically.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;

    // ── SHELL SURVIVABILITY ────────────────────────────────────────────
    //
    // Shell choice was previously gated on `authStatusProvider`, which
    // returns `loading` whenever `sessionBootstrapProvider` is loading
    // and `unauthed` whenever `tokenStore.isAuthed` is false (the
    // `isAuthed` getter applies a 30s JWT-expiry skew, so it flips to
    // false briefly before the silent refresh rotates the token). Either
    // signal flipping mid-session bounced the shell from MemberShell
    // back to PublicShell, which:
    //   * tore down every authed surface (Works/thread/feed/realtime),
    //   * disposed the AuraIncomingLiveLayer mounted inside MemberShell
    //     and dropped any in-flight ringing card,
    //   * showed up to the user as the "everything flashes / shell
    //     disappears for a moment" cross-platform regression.
    //
    // The token's mere PRESENCE is the durable session signal: it's
    // populated for the entire lifetime of a session and is only cleared
    // by an explicit logout / clearTokens(). Choosing the shell from
    // that signal keeps MemberShell alive through routine bootstrap
    // re-runs and through the brief JWT-expiry → refresh round-trip,
    // and only flips back to PublicShell on a real auth drop.
    final store = ref.watch(tokenStoreProvider);
    final isAuthed =
        store.isLoaded && (store.accessToken?.trim().isNotEmpty ?? false);

    final Widget shell;
    final String chose;
    if (isAdminShellPath(path)) {
      shell = AdminShell(child: child);
      chose = 'AdminShell';
    } else if (isInstitutionShellPath(path)) {
      shell = InstitutionShell(child: child);
      chose = 'InstitutionShell';
    } else if (isAuthed) {
      shell = MemberShell(child: child);
      chose = 'MemberShell';
    } else {
      shell = PublicShell(child: child);
      chose = 'PublicShell';
    }
    RuntimeTrace.emit(
      'shell.build',
      'selected shell',
      data: {'chose': chose, 'path': path, 'authed': isAuthed},
    );
    return shell;
  }
}
