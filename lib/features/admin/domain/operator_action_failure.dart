/// WHETHER IT IS SAFE TO OFFER "TRY AGAIN".
///
/// A governed action is not a read. Suspending a person, approving a
/// verification, revoking a grant or sending a consequence changes the world
/// and writes a record, and doing it twice is not a retry — it is a second
/// governed act by an operator who believed the first one failed.
///
/// The action sheet used to treat every failure the same way: show
/// `e.toString()` and offer Retry. That is correct for exactly one kind of
/// failure and dangerous for the rest. A request that timed out, or whose
/// connection dropped after it was sent, may already have been committed by the
/// server; the operator simply never saw the answer. Offering them Retry there
/// is the console encouraging a duplicate.
///
/// So failures are classified by ONE question — *could this already have taken
/// effect?* — and the answer decides what the console offers.
library;

import 'package:dio/dio.dart';

/// What the console is entitled to conclude about a failed governed action.
enum OperatorActionFailure {
  /// The server understood the request and refused it. Any 4xx: the action did
  /// NOT happen, nothing was written, and the operator may safely try again
  /// once whatever was wrong is addressed.
  refused,

  /// The outcome is unknown. A timeout, a dropped connection, or a server error
  /// after the request was accepted. The action MAY have taken effect.
  ///
  /// The console must not offer Retry here. It offers to go and look.
  ambiguous,
}

extension OperatorActionFailureFacts on OperatorActionFailure {
  /// Whether repeating the action is safe to encourage.
  bool get mayRetry => this == OperatorActionFailure.refused;

  /// Whether the operator must re-read authority before deciding anything.
  bool get mustReRead => this == OperatorActionFailure.ambiguous;
}

/// Classify a thrown error from a governed action.
///
/// DELIBERATELY CONSERVATIVE. Only an explicit 4xx counts as "did not happen",
/// because that is the only case where the server both received the request and
/// told us it declined to act on it. Everything else — no response at all, a
/// timeout, a 5xx — is ambiguous, because Dio cannot tell us whether the bytes
/// arrived and were committed before the failure.
///
/// Guessing the safer-sounding way round would be the expensive mistake: a
/// duplicate suspension is a real governed act against a real person, while an
/// unnecessary "go and check" costs one screen.
OperatorActionFailure classifyActionFailure(Object error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code != null && code >= 400 && code < 500) {
      return OperatorActionFailure.refused;
    }
  }
  return OperatorActionFailure.ambiguous;
}

/// What to tell the operator, written about the ACTION rather than the wire.
///
/// The previous version rendered `e.toString()`, which puts a Dio exception in
/// front of someone deciding whether a person is suspended. It also said "Try
/// again" for every failure, including the ones where trying again is the
/// wrong instruction.
String operatorActionFailureSentence(
  OperatorActionFailure failure, {
  required String actionLabel,
}) =>
    switch (failure) {
      OperatorActionFailure.refused =>
        'Aura refused this action, so nothing has changed. '
            '$actionLabel has not been recorded.',
      OperatorActionFailure.ambiguous =>
        'Aura could not confirm the outcome, so this may already have taken '
            'effect. Check the current state before acting again — repeating '
            '$actionLabel would be a second governed action, not a retry.',
    };
