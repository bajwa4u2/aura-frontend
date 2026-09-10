/// THE PAIR, NOT EITHER HALF.
///
/// Production, 2026-09-10. The deployed backend refused an ineligible
/// applicant exactly as designed:
///
///     403  {"ok":false,"error":{"code":"ACCOUNT_AGE_INELIGIBLE",
///           "message":"You need to be at least 16 to have an Aura account.",
///           "details":{"resolvable":false}}}
///
/// and the deployed web client showed:
///
///     "We could not create your account right now. Please try again."
///
/// Both mappers were individually correct. `AuthRepository` turned the CODE
/// into the right sentence. The screen then re-mapped that SENTENCE, matched
/// none of its own branches, and fell through to the generic retry line —
/// erasing the reason and inviting exactly the retry the policy records as not
/// resolvable (`resolvable: false`), which is the prompt that teaches someone
/// to enter a different date of birth.
///
/// So these tests hold BOTH halves at once: a real `Dio` answering with the
/// real production envelope, the real repository, and the real screen copy.
/// A test over either file alone passes on a broken build — which is why the
/// defect shipped past a green suite.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/auth/auth_repository.dart';
import 'package:aura/features/auth/presentation/auth_screen.dart';
import 'package:aura/features/auth/presentation/register_screen.dart';

/// Answers every request with one canned status and body, exactly as the wire
/// would. Nothing here is stricter or more forgiving than the real transport;
/// a fake that is kinder than the network certifies the fake.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.status, this.body);

  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AuthRepository _repoAnswering(int status, String json) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))
    ..httpClientAdapter = _CannedAdapter(status, json);
  return AuthRepository(dio);
}

/// The envelope the deployed backend actually emits, transcribed from a live
/// response rather than read off the handler.
String _envelope(String code, String message, {String details = 'null'}) =>
    '{"ok":false,"error":{"code":"$code","message":"$message",'
    '"details":$details,"requestId":"00000000-0000-0000-0000-000000000000",'
    '"timestamp":"2026-09-10T03:28:27.208Z","path":"/v1/auth/register"}}';

Future<Object> _registerFailure(int status, String json) async {
  try {
    await _repoAnswering(status, json).register(
      email: 'someone@example.test',
      password: 'AuraCert123!',
      firstName: 'A',
      lastName: 'B',
      handle: 'ab',
      displayName: 'A B',
      dateOfBirth: '2012-09-09',
      jurisdiction: 'DE',
      termsAccepted: true,
      termsAcceptedVersion: '2026-05-26',
    );
  } catch (e) {
    return e;
  }
  fail('the repository must not treat $status as a success');
}

Future<Object> _loginFailure(int status, String json) async {
  try {
    await _repoAnswering(status, json)
        .login(email: 'someone@example.test', password: 'x');
  } catch (e) {
    return e;
  }
  fail('the repository must not treat $status as a success');
}

void main() {
  group('join — the refusal reaches the person', () {
    test('an age refusal names the floor, and never says "try again"', () async {
      final error = await _registerFailure(
        403,
        _envelope(
          'ACCOUNT_AGE_INELIGIBLE',
          'You need to be at least 16 to have an Aura account.',
          details: '{"resolvable":false}',
        ),
      );

      final shown = humanizeRegisterError(error);

      expect(
        shown,
        'You need to be at least 16 to have an Aura account.',
        reason: 'the server named the floor and the person must be told it',
      );
      expect(
        shown.toLowerCase(),
        isNot(contains('try again')),
        reason: 'the policy records this refusal as resolvable:false — '
            'inviting a retry invites a different date of birth',
      );
    });

    test('the copy carries whichever floor applies, not a hard-coded one',
        () async {
      final error = await _registerFailure(
        403,
        _envelope(
          'ACCOUNT_AGE_INELIGIBLE',
          'You need to be at least 13 to have an Aura account.',
          details: '{"resolvable":false}',
        ),
      );

      // The floor is jurisdictional — 13 in the US bucket, 16 in EU/EEA and
      // RoW — so a client that hard-codes either number is wrong for most of
      // the world. Both numbers were observed live on 2026-09-10 from the same
      // date of birth under two different declared jurisdictions.
      expect(humanizeRegisterError(error), contains('at least 13'));
    });

    test('a missing date of birth says what to do, not "try again"', () async {
      final error = await _registerFailure(
        403,
        _envelope('DOB_REQUIRED', 'Enter your date of birth to create an account.'),
      );
      final shown = humanizeRegisterError(error);
      expect(shown, contains('date of birth'));
      expect(shown.toLowerCase(), isNot(contains('try again')));
    });

    test('a missing jurisdiction says what to do, not "try again"', () async {
      final error = await _registerFailure(
        403,
        _envelope(
          'JURISDICTION_REQUIRED',
          'Select where you are to create an account.',
        ),
      );
      final shown = humanizeRegisterError(error);
      expect(shown, contains('where you are'));
      expect(shown.toLowerCase(), isNot(contains('try again')));
    });

    test('a genuinely unknown failure still gets the generic line', () async {
      // The guard must not turn every error into raw server text. An
      // unrecognised code has no better sentence to offer, and the generic
      // line is the honest answer there. Without this case the fix could be
      // "return the server string always", which would leak internals.
      final error = await _registerFailure(400, _envelope('SOMETHING_NEW', ''));
      expect(
        humanizeRegisterError(error),
        'Some details need another look. Please review the form and try again.',
      );
    });
  });

  group('sign in — the two sentences that matched no branch', () {
    test('an unavailable account is not reported as "try again"', () async {
      final error = await _loginFailure(
        403,
        _envelope('ACCOUNT_UNAVAILABLE', 'This account is not available right now.'),
      );
      final shown = humanizeLoginError(error);
      expect(
        shown,
        'This account is not available right now.',
        reason: 'the repository maps 403 to this sentence, and it contains none '
            'of disabled / locked / suspended / forbidden — so the screen own '
            'branches never matched it',
      );
      expect(shown.toLowerCase(), isNot(contains('please try again')));
    });

    test('a server-side failure is reported as ours, not as the person fault',
        () async {
      final error = await _loginFailure(500, _envelope('INTERNAL', 'boom'));
      expect(
        humanizeLoginError(error),
        'Something went wrong on our side. Please try again in a moment.',
        reason: 'this sentence contains neither "500" nor "server error", so '
            'the screen own branches never matched it either',
      );
    });

    test('bad credentials still read as bad credentials', () async {
      final error = await _loginFailure(
        401,
        _envelope('UNAUTHORIZED', 'Invalid credentials'),
      );
      expect(
        humanizeLoginError(error),
        'The email or password does not look right.',
      );
    });
  });
}
