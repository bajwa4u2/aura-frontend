import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/route_targets.dart';
import '../net/dio_provider.dart';
import 'auth_providers.dart';
import 'session_providers.dart';

/// SIGNING OUT IS ONE ACT, SO IT HAS ONE IMPLEMENTATION.
///
/// It used to live inside the header's account menu. The mobile chrome
/// reconstruction (founder ruling 2026-08-23) moves account into the drawer,
/// and two copies of "end this session" is exactly the kind of duplication
/// that drifts: one clears the token store, the other forgets to, and the
/// difference only shows up when someone is trying to leave.
///
/// The order matters and is deliberate. The server is told first, because a
/// local clear that races ahead leaves a live server session nobody can reach
/// to revoke. The local clear then runs in a `finally`, so a network failure
/// still ends the session on this device — refusing to sign out because the
/// network is down would be the wrong answer to "get me out".
Future<void> signOutAura(BuildContext context, WidgetRef ref) async {
  final currentPath = GoRouterState.of(context).uri.path;
  final returnPath =
      shouldUseMemberShellForAuthed(currentPath) ? currentPath : '/public';

  final container = ProviderScope.containerOf(context, listen: false);

  try {
    await container.read(dioProvider).post('/auth/logout');
  } catch (_) {
    // Best effort: see above.
  }

  try {
    await container.read(tokenStoreProvider).clear();
    container.invalidate(emailVerifiedProvider);
    container.invalidate(authStatusProvider);
    container.invalidate(isAuthedProvider);
  } finally {
    if (context.mounted) context.go(returnPath);
  }
}
