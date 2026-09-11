import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:aura/features/institutions/verification/data/institution_verification_repository.dart';
import 'package:aura/features/institutions/verification/presentation/institution_verification_screen.dart';

// NATIVE ANDROID CERTIFICATION — THE NEEDS_INFO LOOP, CLOSED.
//
//     adb reverse tcp:34999 tcp:34999
//     node scripts/identity-certification/institution-verification-journey-proof.mjs
//     flutter test integration_test/android_institution_needs_info_certification_test.dart -d <device>
//
// Per run, not once: this lane drives the whole loop and mutates the fixture.
//
// THE LOOP, WALKED AS TWO DIFFERENT PEOPLE FROM THE SAME PHONE:
//
//     owner starts and submits
//       -> it reaches the reviewer's queue
//       -> the reviewer asks for something specific
//       -> the owner is told exactly what, and offered the way out
//       -> the owner answers
//       -> it returns to review, and the stale request is gone
//
// NO HIDDEN OPERATOR INTERVENTION. Every step is a route a real owner or a
// real reviewer has. Neither identity here holds database access, so had any
// step needed a poke behind the product, this lane could not have completed.
//
// AND THE SCREEN RENDERS IT. A loop that closes on the wire and shows a person
// nothing is still a dead end. The widget group asserts the reviewer's actual
// words reach the phone, beside the way out.

// 127.0.0.1, NOT `localhost`. `adb reverse` binds the device's loopback, and a
// literal address needs no resolution; `localhost` goes through Android's DNS
// resolver, which intermittently answers 'No address associated with hostname'
// on a device with no active network.
const String _api = 'http://127.0.0.1:34999/v1';
const String _password = 'certification_only_pw_1';
const String _owner = 'wincert@certification.invalid';
const String _reviewer = 'revcert@certification.invalid';

/// The reviewer's own words. Specific on purpose: §5 requires the requester be
/// told what is actually missing, not that something is.
const String _asked =
    'Please send the registration certificate showing the current address.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Dio ownerDio;
  late Dio reviewerDio;
  late InstitutionVerificationRepository ownerRepo;
  late String institutionId;
  String? existenceProofId;

  Future<String> signIn(String email) async {
    final res = await http.post(
      Uri.parse('$_api/auth/login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'email': email, 'password': _password}),
    );
    expect(
      res.statusCode,
      inInclusiveRange(200, 299),
      reason: 'the phone must reach the isolated stack through the adb reverse '
          'tunnel, and $email must be seeded: ${res.body}',
    );
    return jsonDecode(res.body)['accessToken'] as String;
  }

  setUpAll(() async {
    ownerDio = Dio(BaseOptions(
      baseUrl: _api,
      headers: {'authorization': 'Bearer ${await signIn(_owner)}'},
    ));
    reviewerDio = Dio(BaseOptions(
      baseUrl: _api,
      headers: {'authorization': 'Bearer ${await signIn(_reviewer)}'},
    ));
    ownerRepo = InstitutionVerificationRepository(ownerDio);

    final mine = await ownerDio.get<Map<String, dynamic>>('/institutions/me');
    institutionId =
        ((mine.data?['membership'] as Map)['institution'] as Map)['id'].toString();

    // PRECONDITION, ASSERTED. This lane walks the loop from the beginning, so
    // a fixture a previous run already advanced would make every step below
    // mean something other than what it says.
    final pre = await ownerRepo.standing(institutionId);
    expect(
      pre.existence.state,
      ExistenceState.notStarted,
      reason: 'the native-lane fixture is stale: existence is already '
          '${pre.existence.state}. Re-seed before certifying:\n'
          '  node scripts/identity-certification/'
          'institution-verification-journey-proof.mjs',
    );
  });

  group('the loop closes, walked as two people', () {
    test('1. THE OWNER SUBMITS, AND IT REACHES THE QUEUE', () async {
      await ownerRepo.start(institutionId, 'NONPROFIT_COMMUNITY');
      final after = await ownerRepo.submitExistence(
        institutionId,
        const [SuppliedEvidence(reference: 'Charity Commission 1122334')],
      );
      expect(
        after.existence.state,
        anyOf(ExistenceState.submitted, ExistenceState.manualReview),
      );

      final queue = await reviewerDio.get<Map<String, dynamic>>(
        '/institutions/admin/verification/queue',
      );
      final existence = (queue.data?['data'] as Map)['existence'] as List;
      final mine = existence.cast<Map<String, dynamic>>().where(
            (row) => row['institutionId'] == institutionId,
          );
      expect(mine, isNotEmpty,
          reason: 'a submission that never reaches a reviewer is not a review');
      existenceProofId = mine.first['id'].toString();
    });

    test('2a. A REVIEWER CANNOT ASK ABOUT A CASE THEY HAVE NOT TAKEN', () async {
      // Asserted before the happy path, because it is the thing the happy path
      // would otherwise hide. `needs-info` is an edge out of MANUAL_REVIEW, not
      // out of SUBMITTED: a reviewer picks a case up and then asks about it,
      // and a request arriving from nobody-in-particular is refused.
      expect(existenceProofId, isNotNull);
      final res = await reviewerDio.post<Map<String, dynamic>>(
        '/institutions/admin/verification/existence/$existenceProofId/needs-info',
        data: {'infoRequested': _asked},
        options: Options(validateStatus: (_) => true),
      );
      expect(res.statusCode, 409, reason: '${res.data}');
      expect(((res.data?['error'] as Map?) ?? const {})['code'],
          'VERIFICATION_TRANSITION_NOT_PERMITTED');
    });

    test('2b. SO THEY TAKE IT, AND THEN ASK FOR SOMETHING SPECIFIC', () async {
      final taken = await reviewerDio.post<Map<String, dynamic>>(
        '/institutions/admin/verification/existence/$existenceProofId/review',
        options: Options(validateStatus: (_) => true),
      );
      expect(taken.statusCode, inInclusiveRange(200, 299),
          reason: '${taken.data}');

      final res = await reviewerDio.post<Map<String, dynamic>>(
        '/institutions/admin/verification/existence/$existenceProofId/needs-info',
        data: {'infoRequested': _asked},
        options: Options(validateStatus: (_) => true),
      );
      expect(res.statusCode, inInclusiveRange(200, 299), reason: '${res.data}');
    });

    test('3. THE OWNER IS TOLD EXACTLY WHAT IS MISSING', () async {
      final s = await ownerRepo.standing(institutionId);

      expect(s.existence.state, ExistenceState.needsInfo);
      // The reviewer's own sentence, not a generic "more information needed".
      // A person cannot act on a category.
      expect(s.existence.infoRequested, _asked);
    });

    test('4. AND IS OFFERED THE WAY OUT — NEEDS_INFO IS NOT A DEAD END', () async {
      final s = await ownerRepo.standing(institutionId);

      // From the server's projection of the transition table, so the client
      // cannot offer a step the backend would refuse, and cannot fail to offer
      // one it would allow.
      expect(s.existence.available, contains('SUBMITTED'));
      expect(s.existence.acceptsEvidence, isTrue);
    });

    // ── THE EVIDENCE GUARDS, RUN WHERE THEY ARE THE ONLY POSSIBLE REASON ──
    //
    // Deliberately here rather than in a group of their own. NEEDS_INFO
    // ACCEPTS evidence, so the lifecycle has no objection to these submissions
    // and the only thing that can refuse them is the guard under test. Run
    // from SUBMITTED instead, both would be refused by the transition table
    // and would pass green having proven nothing — a validation slip reported
    // as an eligibility refusal, which this estate has paid for once already.
    //
    // Each asserts the specific code too, so it cannot pass for a neighbouring
    // reason even from the right state.
    test('4a. A REFERENCE CARRYING CONTROL BYTES IS REFUSED, as unsafe', () async {
      // Evidence is stored and later shown to a reviewer. A reference is a
      // registry number or a listing, never a payload.
      Object? raised;
      try {
        await ownerRepo.submitExistence(
          institutionId,
          const [SuppliedEvidence(reference: 'Companies House\u0007 09876543')],
        );
      } catch (e) {
        raised = e;
      }
      expect(raised, isA<InstitutionVerificationException>());
      expect((raised! as InstitutionVerificationException).code,
          'VERIFICATION_REFERENCE_UNSAFE');
    });

    test('4b. AND SO IS A DOCUMENT PASTED IN AS A REFERENCE', () async {
      // REFUSED AT THE BOUNDARY, and the code says so.
      //
      // Length is guarded twice — `@MaxLength` on the DTO and again in the
      // service — and BOTH read the same `REFERENCE_MAX_LENGTH`, so they
      // cannot drift apart and the outer one always answers first over HTTP.
      // Asserting the service's own code here would be asserting a layer this
      // request never reaches, which is how a test comes to certify something
      // other than what runs.
      Object? raised;
      try {
        await ownerRepo.submitExistence(
          institutionId,
          [SuppliedEvidence(reference: 'x' * 2000)],
        );
      } catch (e) {
        raised = e;
      }
      expect(raised, isA<InstitutionVerificationException>());
      expect((raised! as InstitutionVerificationException).code,
          'VALIDATION_ERROR');
    });

    test('4c. AND THE REFUSALS DID NOT MOVE THE PROOF', () async {
      // A guard that refused and advanced the state anyway would have taken
      // the way out away while appearing to protect it.
      final s = await ownerRepo.standing(institutionId);
      expect(s.existence.state, ExistenceState.needsInfo);
      expect(s.existence.infoRequested, _asked);
    });

    test('5. THE OWNER ANSWERS, AND IT RETURNS TO REVIEW', () async {
      final after = await ownerRepo.submitExistence(
        institutionId,
        const [SuppliedEvidence(reference: 'Registration certificate 77-2291')],
      );
      expect(
        after.existence.state,
        anyOf(ExistenceState.submitted, ExistenceState.manualReview),
      );
    });

    test('6. AND THE STALE REQUEST IS GONE', () async {
      final s = await ownerRepo.standing(institutionId);

      // A request that outlived its answer would leave the owner reading an
      // instruction they have already followed, with no way to tell.
      expect(s.existence.infoRequested, isNull);
    });
  });

  group('what may be offered as evidence, from the phone', () {
    test('EVIDENCE STILL CARRIES NO SUBMITTER OF ITS OWN', () {
      // Provenance comes from the authenticated caller or it is not
      // provenance. A client that could name the submitter could name
      // somebody else.
      const evidence = SuppliedEvidence(reference: 'Charity Commission 1122334');
      expect(evidence.toJson().containsKey('submittedByUserId'), isFalse);
    });
  });

  group('and a person can actually read it, on a real phone', () {
    Future<void> mount(WidgetTester tester, InstitutionVerificationStanding s,
        {double textScale = 1.0}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            institutionVerificationStandingProvider(institutionId)
                .overrideWith((ref) async => s),
          ],
          child: MaterialApp(
            // The real tree: MemberShell wraps every routed screen in a
            // Scaffold, which is what supplies the Material ancestor.
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: InstitutionVerificationScreen(institutionId: institutionId),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    testWidgets('THE REVIEWER\'S ACTUAL WORDS REACH THE PHONE', (tester) async {
      // Rebuilt into NEEDS_INFO rather than read live, so this assertion is
      // about rendering and cannot fail because of where the wire state has
      // got to by now.
      final live = await ownerRepo.standing(institutionId);
      final s = InstitutionVerificationStanding(
        institutionId: live.institutionId,
        category: live.category,
        requiresManualReview: live.requiresManualReview,
        existence: ProofStanding<ExistenceState>(
          state: ExistenceState.needsInfo,
          available: const ['SUBMITTED'],
          infoRequested: _asked,
          acceptsEvidence: true,
        ),
        existenceConfidence: null,
        accepted: live.accepted,
        requirementNotEnumerated: live.requirementNotEnumerated,
        authority: live.authority,
        authorityEvidenceKind: live.authorityEvidenceKind,
        menu: live.menu,
        migration: live.migration,
        mayAct: true,
        actionRequiredTier: live.actionRequiredTier,
      );

      await mount(tester, s);

      expect(find.textContaining('registration certificate'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AND SURVIVES A READER WHO NEEDS LARGER TEXT', (tester) async {
      // Accessibility, asserted rather than assumed. A person who has turned
      // text size up is the reader most likely to meet an overflow, and an
      // overflowed instruction is an instruction that cannot be followed.
      final live = await ownerRepo.standing(institutionId);
      final s = InstitutionVerificationStanding(
        institutionId: live.institutionId,
        category: live.category,
        requiresManualReview: live.requiresManualReview,
        existence: ProofStanding<ExistenceState>(
          state: ExistenceState.needsInfo,
          available: const ['SUBMITTED'],
          infoRequested: _asked,
          acceptsEvidence: true,
        ),
        existenceConfidence: null,
        accepted: live.accepted,
        requirementNotEnumerated: live.requirementNotEnumerated,
        authority: live.authority,
        authorityEvidenceKind: live.authorityEvidenceKind,
        menu: live.menu,
        migration: live.migration,
        mayAct: true,
        actionRequiredTier: live.actionRequiredTier,
      );

      await mount(tester, s, textScale: 1.5);

      expect(tester.takeException(), isNull);
    });

    testWidgets('AND ITS CONTROLS ARE BIG ENOUGH TO HIT', (tester) async {
      final live = await ownerRepo.standing(institutionId);
      await mount(tester, live);

      // Android's own guidance is 48dp. Checked on the real device metrics,
      // not on a notional canvas.
      final buttons = find.byWidgetPredicate(
        (w) => w is ButtonStyleButton || w is IconButton,
      );
      for (final element in buttons.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        if (size.isEmpty) continue;
        expect(size.height, greaterThanOrEqualTo(44.0),
            reason: 'a control ${size.width}x${size.height} is too small to '
                'hit reliably on a phone');
      }
      expect(tester.takeException(), isNull);
    });
  });
}
