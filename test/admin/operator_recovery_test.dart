import 'package:aura/features/admin/domain/operator_action_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// RECOVERY MUST NOT INVITE A SECOND GOVERNED ACT.
///
/// A read that fails can be retried freely — nothing happened. A governed
/// action cannot. Suspending a person, approving a verification, revoking a
/// grant or sending a consequence changes the world and writes a record, and
/// doing it twice is not a retry: it is a second governed act by an operator
/// who believed the first one failed.
///
/// The action sheet used to show `e.toString()` and offer Retry for every
/// failure alike, including the ones where the request may already have been
/// committed and the operator simply never saw the answer. These tests hold the
/// line that replaced it, and they hold it in the conservative direction: the
/// console only says "nothing happened" when the server told it so.
DioException _refused(int code) => DioException(
      requestOptions: RequestOptions(path: '/admin/users/u1/suspend'),
      response: Response(
        requestOptions: RequestOptions(path: '/admin/users/u1/suspend'),
        statusCode: code,
      ),
    );

DioException _typed(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/admin/users/u1/suspend'),
      type: type,
    );

void main() {
  group('a refusal is known not to have happened', () {
    test('every 4xx is a refusal, and refusals may be retried', () {
      for (final code in [400, 401, 403, 404, 409, 422, 429, 499]) {
        final failure = classifyActionFailure(_refused(code));
        expect(failure, OperatorActionFailure.refused, reason: 'HTTP $code');
        expect(failure.mayRetry, isTrue, reason: 'HTTP $code');
        expect(failure.mustReRead, isFalse, reason: 'HTTP $code');
      }
    });

    test('a refusal says plainly that nothing was recorded', () {
      final sentence = operatorActionFailureSentence(
        OperatorActionFailure.refused,
        actionLabel: 'Suspend this account',
      );
      expect(sentence, contains('nothing has changed'));
      expect(sentence, contains('has not been recorded'));
    });
  });

  group('anything else may already have taken effect', () {
    test('a timeout is ambiguous, never a refusal', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(classifyActionFailure(_typed(type)),
            OperatorActionFailure.ambiguous,
            reason: '$type — the request may have been committed before the '
                'answer was lost');
      }
    });

    test('a dropped connection is ambiguous', () {
      expect(
        classifyActionFailure(_typed(DioExceptionType.connectionError)),
        OperatorActionFailure.ambiguous,
      );
    });

    test('a 5xx is ambiguous — the server got it and then failed', () {
      for (final code in [500, 502, 503, 504]) {
        expect(classifyActionFailure(_refused(code)),
            OperatorActionFailure.ambiguous,
            reason: 'HTTP $code arrives after the request was accepted');
      }
    });

    test('a non-Dio error is ambiguous rather than assumed harmless', () {
      expect(classifyActionFailure(StateError('anything at all')),
          OperatorActionFailure.ambiguous);
      expect(classifyActionFailure('a bare string'),
          OperatorActionFailure.ambiguous);
    });

    test('ambiguity forbids retry and requires re-reading authority', () {
      const failure = OperatorActionFailure.ambiguous;
      expect(failure.mayRetry, isFalse,
          reason: 'offering Retry here is the console inviting a duplicate');
      expect(failure.mustReRead, isTrue);
    });

    test('the sentence sends the operator to look, not to repeat', () {
      final sentence = operatorActionFailureSentence(
        OperatorActionFailure.ambiguous,
        actionLabel: 'Suspend this account',
      );
      expect(sentence, contains('may already have taken effect'));
      expect(sentence, contains('Check the current state'));
      expect(sentence, contains('second governed action'));
      expect(sentence.toLowerCase(), isNot(contains('try again')),
          reason: 'the one instruction that must never appear here');
    });
  });

  group('the conservative direction is deliberate', () {
    test('an unknown failure is never classified as safe', () {
      // The expensive mistake is one-directional. A duplicate suspension is a
      // real governed act against a real person; an unnecessary "go and check"
      // costs one screen. Anything the console cannot positively identify as a
      // refusal must land on the cautious side.
      final unknowns = <Object>[
        _typed(DioExceptionType.unknown),
        _typed(DioExceptionType.badCertificate),
        _typed(DioExceptionType.cancel),
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: null,
          ),
        ),
        Exception('opaque'),
      ];
      for (final e in unknowns) {
        expect(classifyActionFailure(e), OperatorActionFailure.ambiguous,
            reason: '$e must not be treated as "did not happen"');
      }
    });

    test('a 3xx is not a refusal either', () {
      expect(classifyActionFailure(_refused(302)),
          OperatorActionFailure.ambiguous,
          reason: 'only 4xx is the server saying it understood and declined');
    });
  });
}
