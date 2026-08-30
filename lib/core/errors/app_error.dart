enum AppErrorType {
  authRequired,
  forbidden,
  notFound,
  validation,
  network,
  timeout,
  cancelled,
  server,
  unknown,
}

class AppErrorAction {
  const AppErrorAction({
    required this.label,
    this.route,
  });

  final String label;
  final String? route;
}

/// Canonical, UI-safe representation of any failure surfaced to a human.
///
/// [message] is always a short, human-readable string — never a raw object,
/// stack trace, or backend internals. [toString] intentionally returns
/// [message] rather than the default `Instance of '...'` so that any call
/// site that accidentally interpolates an [AppError] directly (`'$error'`)
/// degrades to readable text instead of a minified class name in release
/// web builds.
class AppError {
  const AppError({
    required this.type,
    required this.message,
    this.action,
    this.debugMessage,
    this.statusCode,
    this.code,
    this.requestId,
    this.issues,
    this.resolvable,
  });

  final AppErrorType type;
  final String message;
  final AppErrorAction? action;
  final String? debugMessage;
  final int? statusCode;

  /// The backend's stable error code (e.g. `VALIDATION_ERROR`), when known.
  final String? code;

  /// The backend request id, kept for diagnostics/support correlation.
  final String? requestId;

  /// Field-level validation issues from `error.details.issues`, when present.
  final List<String>? issues;

  /// `error.details.resolvable`, when the backend states it.
  ///
  /// Whether the PERSON can do something that makes this succeed. A refusal
  /// that only time can lift (an age threshold) is `false`, and a UI that
  /// offers a retry anyway invites a person to press a button that cannot
  /// work. Null means the backend did not say — treated as "do not offer a
  /// retry", because silence is not permission to promise one.
  final bool? resolvable;

  bool get isAuthRequired => type == AppErrorType.authRequired;
  bool get hasIssues => issues != null && issues!.isNotEmpty;

  static const signInAction = AppErrorAction(
    label: 'Sign in',
    route: '/login',
  );

  @override
  String toString() => message;
}
