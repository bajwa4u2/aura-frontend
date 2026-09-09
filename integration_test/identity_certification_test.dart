import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/auth/session_providers.dart';

// NATIVE IDENTITY CERTIFICATION — WINDOWS DESKTOP (a released Aura client).
//
//     flutter test integration_test/identity_certification_test.dart -d windows
//
// WHY THIS SIGNS IN, WHEN desktop_lifecycle_test DELIBERATELY DOES NOT.
//
// That test's refusal is about PRODUCTION credentials, and it still stands.
// This one authenticates against the ISOLATED certification stack with an
// account created through the ordinary registration flow, whose password is a
// fixture literal in an ephemeral tmpfs database that is destroyed with the
// container. No production credential is read, typed or stored, and no token
// is injected: the session is obtained by POSTing to /auth/login exactly as
// the app does.
//
// WHAT IT CERTIFIES. That on Windows — real platform, real networking stack,
// real plugin registration — a LEGACY member resolves as admitted and is NOT
// held at a completion wall, using the client's own identity logic rather
// than a reimplementation of it. The response is fed through the real
// `IdentityState` so `mustCompleteBeforeUse` is the shipped computation.
//
// WHAT IT DOES NOT CERTIFY. It does not drive the UI. Synthetic OS input into
// a Flutter desktop window proved unreliable here — clicks land wrongly after
// layout reflow, Tab does not move focus between text fields, and the wheel
// does not reach the auth card's inner scrollable. Windows UI interaction is
// therefore reported EVIDENCE-LIMITED rather than inferred from Web, per the
// founder's cross-platform rule. Booting the whole app in-process is also
// avoided on purpose: the real router starts network work that outlives the
// test and Flutter then reports "this test failed after it had already
// completed".
//
// Requires the certification stack up and reachable on 34999.
const String _api = 'http://localhost:34999/v1';
const String _email = 'legacy2@certification.invalid';
const String _password = 'certification_only_pw_1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('identity on Windows, against the branch backend', () {
    late Map<String, dynamic> me;

    setUpAll(() async {
      final login = await http.post(
        Uri.parse('$_api/auth/login'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'email': _email, 'password': _password}),
      );
      expect(
        login.statusCode,
        inInclusiveRange(200, 299),
        reason: 'legitimate sign-in must succeed: ${login.body}',
      );

      final decoded = jsonDecode(login.body) as Map<String, dynamic>;
      final data = (decoded['data'] ?? decoded) as Map<String, dynamic>;
      final token = (data['accessToken'] ?? data['token']) as String?;
      expect(token, isNotNull, reason: 'no access token in: ${login.body}');

      final meRes = await http.get(
        Uri.parse('$_api/auth/me'),
        headers: {'authorization': 'Bearer $token'},
      );
      expect(meRes.statusCode, 200);
      final meDecoded = jsonDecode(meRes.body) as Map<String, dynamic>;
      // The identity signals sit on `data` as SIBLINGS of `data.user` — they
      // are derived, not columns. Reading the row instead of the projection is
      // the mistake the single-contract design exists to prevent.
      me = (meDecoded['data'] ?? meDecoded) as Map<String, dynamic>;
    });

    test('a legacy member is admitted by CONTINUITY', () {
      expect(me['admissionBasis'], 'CONTINUITY');
    });

    test('completeness is reported honestly, not flattered', () {
      expect(me['identityBaselineComplete'], isFalse);
      expect(me['identityMissingFields'], isNotEmpty);
    });

    testWidgets('and is NEVER held at a completion wall', (tester) async {
      // The shipped computation, not a restatement of it.
      final container = ProviderContainer(
        overrides: [
          isAuthedProvider.overrideWithValue(true),
          authMeDataProvider.overrideWith((ref) async => me),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(identityStateProvider.future);

      expect(state, isNotNull);
      expect(state!.admissionBasis, AdmissionBasis.continuity);
      expect(state.baselineComplete, isFalse);

      // THE ASSERTION THIS WHOLE BRANCH EXISTS FOR.
      expect(
        state.mustCompleteBeforeUse,
        isFalse,
        reason: 'a continuity member must never be held at a door',
      );

      // Incomplete AND not held means Aura may still invite them to fill gaps.
      expect(state.shouldInviteCompletion, isTrue);
    });

    testWidgets('an unrecognised admission reads as CONTINUITY, never PROSPECTIVE',
        (tester) async {
      // Production main does not emit this field at all yet. Guessing
      // prospective would hold a legacy member at a door they should never see.
      final unknown = Map<String, dynamic>.from(me)
        ..['admissionBasis'] = 'SOMETHING_NEW';
      final container = ProviderContainer(
        overrides: [
          isAuthedProvider.overrideWithValue(true),
          authMeDataProvider.overrideWith((ref) async => unknown),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(identityStateProvider.future);
      expect(state!.admissionBasis, AdmissionBasis.continuity);
      expect(state.mustCompleteBeforeUse, isFalse);
    });
  });
}
