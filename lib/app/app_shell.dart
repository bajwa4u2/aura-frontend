import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'route_classification.dart';
import '../core/auth/session_providers.dart';
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
    final isAuthed =
        ref.watch(authStatusProvider) == AuthStatus.authed;

    if (isAdminShellPath(path)) {
      return AdminShell(child: child);
    }
    if (isInstitutionShellPath(path)) {
      return InstitutionShell(child: child);
    }
    if (isAuthed) {
      return MemberShell(child: child);
    }
    return PublicShell(child: child);
  }
}
