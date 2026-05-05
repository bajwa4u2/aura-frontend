import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import '../institutions/institution_access_provider.dart';
import 'actor_context.dart';
import 'direct_threads_repository.dart';
import 'follows_repository.dart';

/// Single source of truth for "tap Message". Every Message CTA in the app
/// MUST go through this method. There is no fallback path. If the call
/// fails, the user gets an error — they never silently land on `/home` or
/// `/messages`.
///
/// Auth handling:
///   * Auth is decided by [isAuthedProvider] (token-loaded + access token
///     present). It is NOT decided by [authStatusProvider] because the
///     latter flips to `loading` during routine `/auth/refresh` round-trips
///     and a brief loading window would otherwise bounce a perfectly
///     authenticated session through `/login` and out the redirect chain
///     into `/home`.
///   * Truly unauthenticated → `/login?redirect=/direct-intent?…` so the
///     thread resumes after sign-in.
///   * Authed but server returns 401 (token rejected mid-flight, refresh
///     failed) → same `/login + intent` redirect.
class InteractionService {
  const InteractionService();

  Future<void> openDirectThread({
    required BuildContext context,
    required WidgetRef ref,
    required ActorRef target,
  }) async {
    final isAuthed = ref.read(isAuthedProvider);
    if (!isAuthed) {
      _routeToLoginIntent(context, target);
      return;
    }

    // Block on /auth/me so we have a stable user id. Bootstrap may still
    // be in flight; the token itself is enough to authorise the API call,
    // and once auth-me resolves we can build the actor body precisely.
    Map<String, dynamic> me;
    try {
      me = await ref.read(authMeDataProvider.future);
    } catch (_) {
      // /auth/me failed — most likely the token is stale and refresh
      // hasn't recovered. Route to login resume.
      if (!context.mounted) return;
      _routeToLoginIntent(context, target);
      return;
    }
    final userBlock = me['user'];
    final userId =
        (userBlock is Map ? userBlock['id']?.toString() ?? '' : '').trim();
    if (userId.isEmpty) {
      throw const InteractionError(
        'Could not resolve your account. Sign in again.',
      );
    }

    if (!context.mounted) return;
    // Pick the actor by shell context: institution shell ⇒ institution
    // actor (when speaker rights apply); otherwise the user.
    final path = GoRouterState.of(context).uri.path;
    final inInstitutionShell =
        path == '/institution' || path.startsWith('/institution/');
    final identity = ref.read(institutionIdentityProvider);
    final ActorRef actor;
    if (inInstitutionShell &&
        identity != null &&
        identity.id.isNotEmpty &&
        (identity.canPublishPosts || identity.isAdmin)) {
      actor = ActorRef.institution(identity.id);
    } else {
      actor = ActorRef.user(userId);
    }

    final repo = ref.read(directThreadsRepositoryProvider);
    DirectThreadInfo info;
    try {
      info = await repo.openOrCreate(actor: actor, target: target);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (!context.mounted) return;
        _routeToLoginIntent(context, target);
        return;
      }
      rethrow;
    }

    if (info.route.isEmpty) {
      throw const InteractionError(
        'Failed to open conversation. Try again.',
      );
    }
    if (!context.mounted) return;
    context.push(info.route);
  }

  void _routeToLoginIntent(BuildContext context, ActorRef target) {
    final intentUri = Uri(
      path: '/direct-intent',
      queryParameters: <String, String>{
        'targetType':
            target.type == ActorType.institution ? 'INSTITUTION' : 'USER',
        if (target.type == ActorType.user) 'targetUserId': target.userId ?? '',
        if (target.type == ActorType.institution)
          'targetInstitutionId': target.institutionId ?? '',
      },
    ).toString();
    final loginUri = Uri(
      path: '/login',
      queryParameters: {'redirect': intentUri},
    ).toString();
    context.go(loginUri);
  }
}

class InteractionError implements Exception {
  const InteractionError(this.message);
  final String message;
  @override
  String toString() => message;
}

final interactionServiceProvider =
    Provider<InteractionService>((_) => const InteractionService());
