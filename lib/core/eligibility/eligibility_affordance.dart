import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_error_mapper.dart';
import 'eligibility_refusal.dart';
import 'jurisdiction_confirm_sheet.dart';

/// THE ONE PLACE A REFUSED PUBLICATION IS EXPLAINED.
///
/// Every publish surface — personal post, reply, repost, institution voice,
/// announcement — can be refused by the same backend gate, so they all render
/// the same three outcomes rather than each inventing its own. The three are
/// not cosmetic variants; they are different promises:
///
///   1. Confirm your country  → one tap, then the act is retried for you.
///   2. Add your date of birth → the identity baseline is missing entirely.
///   3. You must be N or older → nothing to press. Say it once, plainly.
///
/// Returns true ONLY when the caller should retry the act it just attempted.
/// In every other case it has already told the person what happened, and the
/// caller's job is simply to stop — with the draft exactly as it was.
Future<bool> handleEligibilityRefusal(
  BuildContext context,
  WidgetRef ref,
  Object error, {
  String? feature,
}) async {
  final refusal = EligibilityRefusal.from(
    AppErrorMapper.from(error, feature: feature),
  );

  // Not an eligibility refusal. The caller's ordinary error path owns it —
  // returning false here must not be read as "handled".
  if (refusal == null) return false;

  if (refusal.needsJurisdiction) {
    final saved = await showJurisdictionConfirmSheet(
      context,
      ref,
      explanation: refusal.message,
    );
    // Dismissed without answering is a real answer. Nothing changed, so there
    // is nothing to retry, and re-showing the sheet would be nagging.
    return saved;
  }

  if (!context.mounted) return false;

  if (refusal.needsDateOfBirth) {
    // The router already forces the baseline screen for anyone missing a date
    // of birth, so reaching this means the two disagree — surface the
    // backend's own sentence rather than silently doing nothing.
    _tell(context, refusal.message);
    return false;
  }

  // Age. Only time resolves it, so there is deliberately no action offered.
  _tell(context, refusal.message);
  return false;
}

void _tell(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
      ),
    );
}
