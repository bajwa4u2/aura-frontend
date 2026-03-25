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

class AppError {
  const AppError({
    required this.type,
    required this.message,
    this.action,
    this.debugMessage,
    this.statusCode,
  });

  final AppErrorType type;
  final String message;
  final AppErrorAction? action;
  final String? debugMessage;
  final int? statusCode;

  bool get isAuthRequired => type == AppErrorType.authRequired;

  static const signInAction = AppErrorAction(
    label: 'Sign in',
    route: '/login',
  );
}
