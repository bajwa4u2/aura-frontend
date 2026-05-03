import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'route_classification.dart';
import 'route_targets.dart';
import '../core/auth/session_providers.dart';
import '../features/realtime/application/realtime_providers.dart';
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
    final isAuthed = ref.watch(isAuthedProvider);
    final liveState = ref.watch(realtimeControllerProvider);
    debugPrint('[APP_SHELL] path=$path authed=$isAuthed isJoined=${liveState.isJoined} child=${child.runtimeType} childKey=${child.key}');

    if (isAdminShellPath(path)) {
      debugPrint('[APP_SHELL] → AdminShell');
      return AdminShell(child: child);
    }
    if (isInstitutionShellPath(path)) {
      debugPrint('[APP_SHELL] → InstitutionShell');
      return InstitutionShell(child: child);
    }
    if (isMemberShellPath(path) ||
        (isAuthed && shouldUseMemberShellForAuthed(path))) {
      debugPrint('[APP_SHELL] → MemberShell');
      return MemberShell(child: child);
    }
    debugPrint('[APP_SHELL] → PublicShell');
    return PublicShell(child: child);
  }
}
