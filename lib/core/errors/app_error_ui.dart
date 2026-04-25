import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_error.dart';

class AppErrorUi {
  const AppErrorUi._();

  static void showSnackBar(
    BuildContext context,
    AppError error, {
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: behavior,
        content: Text(error.message),
        action: error.action == null
            ? null
            : SnackBarAction(
                label: error.action!.label,
                onPressed: () {
                  final route = error.action!.route;
                  if (route != null && route.isNotEmpty) {
                    context.go(route);
                  }
                },
              ),
      ),
    );
  }
}

class AppInlineError extends StatelessWidget {
  const AppInlineError({
    super.key,
    required this.error,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.textAlign,
  });

  final AppError error;
  final EdgeInsetsGeometry padding;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.82);

    return Padding(
      padding: padding,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Text(
            error.message,
            textAlign: textAlign,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
          ),
          if (error.action?.route != null)
            TextButton(
              onPressed: () => context.go(error.action!.route!),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              child: Text(error.action!.label),
            ),
        ],
      ),
    );
  }
}
