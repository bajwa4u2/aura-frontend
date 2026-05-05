import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'route_classification.dart';
import 'route_targets.dart';
import '../core/auth/session_providers.dart';
import 'shell/admin_shell.dart';
import 'shell/member_shell.dart';
import 'shell/public_shell.dart';

export 'shell/admin_shell.dart' show AdminShell;
export 'shell/member_shell.dart' show MemberShell, InstitutionShell;
export 'shell/public_shell.dart' show PublicShell;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    // Use authStatusProvider (bootstrap-aware) instead of isAuthedProvider so
    // a logged-in user landing on a public-looking URL during the
    // /auth/refresh round-trip is not briefly rendered with the public shell.
    final isAuthed =
        ref.watch(authStatusProvider) == AuthStatus.authed;
    if (isAdminShellPath(path)) {
      return AdminShell(child: child);
    }
    if (isInstitutionShellPath(path)) {
      return InstitutionShell(child: child);
    }
    if (isMemberShellPath(path) ||
        (isAuthed && shouldUseMemberShellForAuthed(path))) {
      return MemberShell(child: child);
    }
    return PublicShell(child: child);
  }
}
