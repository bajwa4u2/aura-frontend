import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A dialog action in each platform's own convention: Cupertino actions on
/// iOS and macOS (inside `AlertDialog.adaptive`), Material text buttons
/// everywhere else. A destructive action reads as destructive on both.
Widget adaptiveDialogAction(
  BuildContext context, {
  required String label,
  required VoidCallback onPressed,
  bool destructive = false,
}) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoDialogAction(
      isDestructiveAction: destructive,
      onPressed: onPressed,
      child: Text(label),
    );
  }
  return TextButton(
    onPressed: onPressed,
    style: destructive
        ? TextButton.styleFrom(foregroundColor: const Color(0xFFE5675C))
        : null,
    child: Text(label),
  );
}
