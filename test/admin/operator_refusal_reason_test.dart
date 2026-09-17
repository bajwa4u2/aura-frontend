import 'package:aura/features/admin/domain/operator_action_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A REFUSAL MUST SAY WHICH RULE REFUSED IT.
///
/// Production, 2026-09-17. An operator holding every admin permission opened a
/// complete identity submission in a reviewable state and pressed "Verify this
/// person's identity". The server refused — correctly, because the submission
/// was the operator's own and a reviewer may never decide their own submission.
/// It said so, in the standard envelope, with a code and a sentence written to
/// be shown.
///
/// The console rendered: "Aura refused this action, so nothing has changed."
/// Then it offered Retry.
///
/// Nothing about that was wrong except everything the operator needed. The
/// sentence is true of every 4xx ever returned, and the Retry could not have
/// succeeded on any attempt. A correct policy refusal was indistinguishable
/// from a broken system, and the only remedy offered was the one that could
/// never work.
///
/// These tests hold the repair: when the server names a reason, the operator
/// sees it; when the rule will refuse forever, Retry is not offered; and when
/// the server names nothing, the console invents nothing.
DioException _refusedWith(
  int status, {
  Object? body,
  String path = '/admin/identity-verification/sub_1/decide',
}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
        data: body,
      ),
    );

/// The exact shape `AuraHttpExceptionFilter` puts on the wire.
Map<String, Object?> _envelope(String code, String message) => {
      'ok': false,
      'error': {
        'code': code,
        'message': message,
        'details': null,
        'requestId': 'req_test',
        'timestamp': '2026-09-17T00:00:00.000Z',
        'path': '/admin/identity-verification/sub_1/decide',
      },
    };

void main() {
  group('the server names the rule, and the operator sees it', () {
    test('self-review is reported as self-review, not as a generic refusal', () {
      final error = _refusedWith(
        403,
        body: _envelope(
          'IDENTITY_VERIFICATION_SELF_REVIEW',
          'You cannot review your own verification.',
        ),
      );

      final refusal = refusalReasonFrom(error)!;
      expect(refusal.code, 'IDENTITY_VERIFICATION_SELF_REVIEW');

      final sentence = operatorActionFailureSentence(
        classifyActionFailure(error),
        actionLabel: "Verify this person's identity",
        refusal: refusal,
      );

      // The reason leads.
      expect(sentence, startsWith('You cannot review your own verification.'));
      // The fact that matters most is still there.
      expect(sentence, contains('Nothing has changed'));
      expect(sentence, contains("Verify this person's identity"));
    });

    test('each distinct rule produces a distinct operator sentence', () {
      final cases = <String, String>{
        'IDENTITY_VERIFICATION_SELF_REVIEW':
            'You cannot review your own verification.',
        'IDENTITY_VERIFICATION_EVIDENCE_INCOMPLETE':
            'This submission cannot be approved on the evidence present.',
        'IDENTITY_VERIFICATION_ALREADY_DECIDED':
            'This submission has already been decided.',
        'IDENTITY_VERIFICATION_REASON_REQUIRED':
            'A reason is required for every decision.',
        'FORBIDDEN': 'Forbidden',
      };

      final sentences = <String>{};
      for (final entry in cases.entries) {
        final error = _refusedWith(403, body: _envelope(entry.key, entry.value));
        final sentence = operatorActionFailureSentence(
          classifyActionFailure(error),
          actionLabel: 'Verify this person',
          refusal: refusalReasonFrom(error),
        );
        expect(sentence, contains(entry.value), reason: entry.key);
        sentences.add(sentence);
      }

      // No two rules may collapse into the same message. That collapse is the
      // defect this file exists for.
      expect(sentences.length, cases.length);
    });
  });

  group('a rule that refuses forever must not offer Retry', () {
    test('self-review and already-decided are terminal', () {
      for (final code in [
        'IDENTITY_VERIFICATION_SELF_REVIEW',
        'IDENTITY_VERIFICATION_ALREADY_DECIDED',
        'FORBIDDEN',
      ]) {
        final refusal = refusalReasonFrom(
          _refusedWith(403, body: _envelope(code, 'because.')),
        )!;
        expect(refusal.isTerminal, isTrue, reason: code);
      }
    });

    test('a fixable refusal stays retryable', () {
      for (final code in [
        'IDENTITY_VERIFICATION_EVIDENCE_INCOMPLETE',
        'IDENTITY_VERIFICATION_REASON_REQUIRED',
        'VALIDATION_ERROR',
      ]) {
        final refusal = refusalReasonFrom(
          _refusedWith(400, body: _envelope(code, 'fix it.')),
        )!;
        expect(refusal.isTerminal, isFalse, reason: code);
      }
    });

    test('retry-safety and retry-usefulness are different questions', () {
      // A refusal is always SAFE to repeat — nothing was written. That is what
      // OperatorActionFailure.mayRetry means, and it must not change here.
      final error = _refusedWith(
        403,
        body: _envelope('IDENTITY_VERIFICATION_SELF_REVIEW', 'no.'),
      );
      expect(classifyActionFailure(error).mayRetry, isTrue);
      // But it is not USEFUL to repeat, which is a separate fact.
      expect(refusalReasonFrom(error)!.isTerminal, isTrue);
    });
  });

  group('the console invents nothing', () {
    test('no envelope means no reason, and the generic sentence stands', () {
      for (final body in <Object?>[
        null,
        'plain text body',
        <String, Object?>{'ok': false},
        <String, Object?>{'error': 'not a map'},
        <String, Object?>{
          'error': {'message': 'no code here'}
        },
        <String, Object?>{
          'error': {'code': ''}
        },
      ]) {
        expect(refusalReasonFrom(_refusedWith(403, body: body)), isNull,
            reason: '$body');
      }

      final sentence = operatorActionFailureSentence(
        OperatorActionFailure.refused,
        actionLabel: 'Verify this person',
        refusal: null,
      );
      expect(sentence, startsWith('Aura refused this action'));
    });

    test('a code with an empty message still reports safely', () {
      final refusal = refusalReasonFrom(
        _refusedWith(403, body: _envelope('SOME_RULE', '   ')),
      )!;
      expect(refusal.code, 'SOME_RULE');
      expect(refusal.message, isNotEmpty);
    });

    test('5xx and transport failures carry no refusal reason', () {
      expect(refusalReasonFrom(_refusedWith(500, body: _envelope('X', 'y'))),
          isNull);
      expect(
        refusalReasonFrom(DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionTimeout,
        )),
        isNull,
      );
      expect(refusalReasonFrom(StateError('nope')), isNull);
    });

    test('an ambiguous failure never adopts a refusal sentence', () {
      // Even if a reason were somehow present, ambiguity outranks it: the
      // action may already have taken effect and that is what must be said.
      final sentence = operatorActionFailureSentence(
        OperatorActionFailure.ambiguous,
        actionLabel: 'Verify this person',
        refusal: const OperatorRefusal(
          code: 'IDENTITY_VERIFICATION_SELF_REVIEW',
          message: 'You cannot review your own verification.',
        ),
      );
      expect(sentence, contains('could not confirm the outcome'));
      expect(sentence, isNot(contains('your own verification')));
    });
  });
}
