import 'package:flutter/material.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';

/// WHY A MEETING PAGE DID NOT OPEN — said truthfully (6 Nov 2026).
///
/// Every failure used to read "This meeting is available to its members."
/// with a Sign in button: a signed-in member who was offline, or who hit a
/// server fault, was told they had no access and offered a sign-in they
/// already had.
enum MeetingLoadProblem {
  /// No connection, or the request timed out.
  offline,

  /// The server failed, or something unexpected happened.
  server,

  /// Signed in, and the server said no (403) or that there is no such
  /// meeting for this person (404).
  noAccess,

  /// Not signed in, or the session is no longer accepted.
  signedOut,
}

MeetingLoadProblem classifyMeetingLoadError(
  Object error, {
  required bool signedIn,
}) {
  if (!signedIn) return MeetingLoadProblem.signedOut;
  final mapped = AppErrorMapper.from(error, feature: 'meetings');
  switch (mapped.type) {
    case AppErrorType.network:
    case AppErrorType.timeout:
      return MeetingLoadProblem.offline;
    case AppErrorType.forbidden:
    case AppErrorType.notFound:
      return MeetingLoadProblem.noAccess;
    case AppErrorType.authRequired:
      return MeetingLoadProblem.signedOut;
    case AppErrorType.validation:
    case AppErrorType.cancelled:
    case AppErrorType.server:
    case AppErrorType.unknown:
      return MeetingLoadProblem.server;
  }
}

/// The full-page state for a meeting that did not load.
class MeetingLoadProblemView extends StatelessWidget {
  const MeetingLoadProblemView({
    super.key,
    required this.problem,
    required this.onRetry,
    required this.onSignIn,
  });

  final MeetingLoadProblem problem;
  final VoidCallback onRetry;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String title, String? body) = switch (problem) {
      MeetingLoadProblem.offline => (
          Icons.cloud_off_rounded,
          "You're offline",
          'This meeting will load when your connection is back.',
        ),
      MeetingLoadProblem.server => (
          Icons.error_outline_rounded,
          "Couldn't load this meeting",
          'Something went wrong on our side. Try again.',
        ),
      MeetingLoadProblem.noAccess => (
          Icons.lock_outline_rounded,
          'This meeting is available to its members.',
          null,
        ),
      MeetingLoadProblem.signedOut => (
          Icons.lock_outline_rounded,
          'This meeting is available to its members.',
          'Sign in to see it.',
        ),
    };
    final retryable = problem == MeetingLoadProblem.offline ||
        problem == MeetingLoadProblem.server;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AuraSurface.faint),
            const SizedBox(height: AuraSpace.s12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: AuraSpace.s6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AuraSurface.muted),
              ),
            ],
            const SizedBox(height: AuraSpace.s16),
            if (retryable)
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: Text(ProductLabels.of(ProductAction.retry)),
                onPressed: onRetry,
              ),
            if (problem == MeetingLoadProblem.signedOut)
              FilledButton.icon(
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in'),
                onPressed: onSignIn,
              ),
          ],
        ),
      ),
    );
  }
}
