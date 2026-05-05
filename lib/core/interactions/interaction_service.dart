import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_providers.dart';
import 'actor_context.dart';
import 'direct_threads_repository.dart';
import 'follows_repository.dart';

/// Single source of truth for "tap Message". Every Message CTA in the app
/// MUST go through this method. There is no fallback path. If the call
/// fails, the user gets an error — they never silently land on `/home` or
/// `/messages`.
///
/// Login resume:
///   * If the user is unauthenticated, they're routed to
///     `/login?redirect=/direct-intent?...`.
///   * `/direct-intent` re-runs this handler post-login.
class InteractionService {
  const InteractionService();

  /// Open or create a direct thread between the active actor and the given
  /// target. Navigates to the thread route the server returned.
  ///
  /// Throws [InteractionError] when the open call fails — the caller is
  /// responsible for showing the error. This method does not navigate
  /// anywhere on failure.
  Future<void> openDirectThread({
    required BuildContext context,
    required WidgetRef ref,
    required ActorRef target,
  }) async {
    final auth = ref.read(authStatusProvider);
    if (auth != AuthStatus.authed) {
      // Login resume: encode the target into a /direct-intent redirect so
      // the post-login bounce reopens the same thread.
      final intentUri = Uri(
        path: '/direct-intent',
        queryParameters: {
          'targetType':
              target.type == ActorType.institution ? 'INSTITUTION' : 'USER',
          if (target.type == ActorType.user)
            'targetUserId': target.userId ?? '',
          if (target.type == ActorType.institution)
            'targetInstitutionId': target.institutionId ?? '',
        },
      ).toString();
      final loginUri = Uri(
        path: '/login',
        queryParameters: {'redirect': intentUri},
      ).toString();
      context.go(loginUri);
      return;
    }

    final actor = resolveActorContext(context, ref);
    if (actor == null) {
      throw const InteractionError('Sign in to send messages');
    }
    final actorRef = actor.isInstitution
        ? ActorRef.institution(actor.institutionId ?? '')
        : ActorRef.user(actor.userId ?? '');
    if (actorRef.id.isEmpty) {
      throw const InteractionError('Sign in to send messages');
    }

    final repo = ref.read(directThreadsRepositoryProvider);
    final info = await repo.openOrCreate(actor: actorRef, target: target);

    // Server-supplied route already encodes the actor's shell. Trust it.
    if (!context.mounted) return;
    context.push(info.route);
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
