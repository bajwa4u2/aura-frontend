import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../institutions/institution_access_provider.dart';

/// Discriminator for actor identity.
enum ActorType { user, institution }

/// Phase-2 active actor used by every interaction button (follow, message,
/// like, reply). Determined by the active shell:
///
///   * `/institution/...` paths      → institution actor (institutionId from
///                                      [institutionIdentityProvider])
///   * any other authenticated path  → user actor
///   * unauthenticated               → null (caller renders Sign in / Join)
class ActorContext {
  const ActorContext({
    required this.type,
    this.userId,
    this.institutionId,
    this.displayName,
    this.avatarUrl,
    this.canSpeakAsInstitution = false,
  });

  final ActorType type;
  final String? userId;
  final String? institutionId;
  final String? displayName;
  final String? avatarUrl;

  /// True when [type] == institution AND the human has speaker rights for
  /// that institution. Buttons that mutate (follow, send DM) require this
  /// to be true on the institution side; reads (state probes) do not.
  final bool canSpeakAsInstitution;

  bool get isInstitution => type == ActorType.institution;
  bool get isUser => type == ActorType.user;

  /// Stable identifier of whatever this actor is. For routing + provider
  /// keys.
  String get id =>
      isInstitution ? (institutionId ?? '') : (userId ?? '');
}

/// True when the path begins with `/institution/` (the institution shell).
/// Anything else falls back to user-actor context.
bool _pathIsInstitutionShell(String path) {
  if (path.isEmpty) return false;
  if (path == '/institution') return true;
  return path.startsWith('/institution/');
}

/// Resolves the active [ActorContext] for the current frame.
///
/// `null` ⇒ the user is unauthenticated. Components MUST handle this
/// (typically by rendering Sign in / Join CTAs instead of follow/message).
ActorContext? resolveActorContext(
  BuildContext context,
  WidgetRef ref,
) {
  final auth = ref.watch(authStatusProvider);
  if (auth != AuthStatus.authed) return null;

  final me = ref.watch(authMeDataProvider).valueOrNull;
  final identity = ref.watch(institutionIdentityProvider);
  final path = GoRouterState.of(context).uri.path;

  // Personal user fallback — display name + avatar pulled from /auth/me when
  // available. Personal id comes from the `user` block of /auth/me.
  String? userId;
  String? userName;
  String? userAvatar;
  if (me != null) {
    final user = me['user'];
    if (user is Map) {
      userId = user['id']?.toString();
      userName = user['displayName']?.toString() ?? user['handle']?.toString();
      userAvatar = user['avatarUrl']?.toString();
    }
  }

  // In institution shell with a loaded institution identity → institution actor.
  if (_pathIsInstitutionShell(path) &&
      identity != null &&
      identity.id.isNotEmpty) {
    return ActorContext(
      type: ActorType.institution,
      userId: userId,
      institutionId: identity.id,
      displayName: identity.name,
      avatarUrl: identity.logoUrl,
      canSpeakAsInstitution:
          identity.canPublishPosts || identity.isAdmin,
    );
  }

  if (userId == null || userId.trim().isEmpty) {
    return null;
  }
  return ActorContext(
    type: ActorType.user,
    userId: userId,
    displayName: userName,
    avatarUrl: userAvatar,
  );
}

/// Provider variant for places that don't have a [BuildContext]. Note that
/// this version cannot inspect the route path so it falls back to user-
/// actor whenever no institution identity is loaded. Components inside the
/// widget tree should prefer [resolveActorContext] above.
final activeActorContextProvider =
    Provider.autoDispose<ActorContext?>((ref) {
  final auth = ref.watch(authStatusProvider);
  if (auth != AuthStatus.authed) return null;

  final me = ref.watch(authMeDataProvider).valueOrNull;
  final identity = ref.watch(institutionIdentityProvider);

  String? userId;
  String? userName;
  String? userAvatar;
  if (me != null) {
    final user = me['user'];
    if (user is Map) {
      userId = user['id']?.toString();
      userName = user['displayName']?.toString() ?? user['handle']?.toString();
      userAvatar = user['avatarUrl']?.toString();
    }
  }

  if (identity != null && identity.id.isNotEmpty) {
    return ActorContext(
      type: ActorType.institution,
      userId: userId,
      institutionId: identity.id,
      displayName: identity.name,
      avatarUrl: identity.logoUrl,
      canSpeakAsInstitution:
          identity.canPublishPosts || identity.isAdmin,
    );
  }
  if (userId == null || userId.trim().isEmpty) return null;
  return ActorContext(
    type: ActorType.user,
    userId: userId,
    displayName: userName,
    avatarUrl: userAvatar,
  );
});
