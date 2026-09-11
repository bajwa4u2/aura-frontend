import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/navigation/canonical_destinations.dart';
import 'package:aura/features/institutions/verification/data/institution_verification_repository.dart';
import 'package:aura/features/institutions/verification/presentation/institution_verification_screen.dart';

// NATIVE ANDROID CERTIFICATION — PHYSICAL PIXEL 9a, Android 17 (API 37).
//
//     adb reverse tcp:34999 tcp:34999
//     flutter test integration_test/android_institution_verification_certification_test.dart -d 53061JEBF08485
//
// WHAT THIS CERTIFIES, and why each part is here rather than inferred:
//
//   REAL PLATFORM, REAL TRANSPORT. Dart on ARM64 Android talking to the
//   isolated stack through an adb reverse tunnel. Nothing about the networking
//   stack, the TLS-less localhost path or plugin registration is borrowed from
//   the Windows or web lanes.
//
//   THE SHIPPED CLIENT CODE. Assertions run through
//   `InstitutionVerificationRepository` and mount the real
//   `InstitutionVerificationScreen`, not restatements of either. A parsing or
//   layout defect that would blank a real person's phone fails here.
//
//   THE GATES, FROM THE PHONE. An account without standing is refused, and the
//   refusal arrives carrying the server's own words AND its machine code.
//
//   MOBILE LAYOUT. The screen is built at a real phone's logical size and
//   asserted not to overflow — the failure mode that only appears on a narrow
//   viewport.
//
// WHAT IT DOES NOT CERTIFY, stated rather than quietly omitted:
//
//   The system file picker, the share sheet and a real upload are NOT driven.
//   Those need OS-level interaction that a Flutter integration test cannot
//   perform, and Android evidence acquisition is reported EVIDENCE_LIMITED
//   rather than inferred from the web build.
//
//   It does not boot the whole app: the real router starts network work that
//   outlives the test and Flutter then reports "this test failed after it had
//   already completed".
//
// Requires the ISOLATED certification stack up on 34999, and the seeder run
// IMMEDIATELY BEFORE EACH CERTIFICATION RUN:
//
//   node scripts/identity-certification/institution-verification-journey-proof.mjs
//
// Per run, not once. This lane drives the journey, which MUTATES the fixture:
// it starts a verification and submits evidence. A second run against an
// already-advanced fixture meets a correct lifecycle refusal, and a correct
// server answer reported as a product failure is the most expensive kind of
// wrong result. The seeder resets the fixture's verification state; `setUpAll`
// below asserts that it did, and says so by name if it did not.

// 127.0.0.1, NOT `localhost`. `adb reverse` binds the device's loopback, and
// a literal address needs no resolution; `localhost` goes through Android's
// DNS resolver, which intermittently answers 'No address associated with
// hostname' on a device with no active network. That failure looks exactly
// like the certification stack being down, and it is not.
const String _api = 'http://127.0.0.1:34999/v1';
const String _password = 'certification_only_pw_1';
const String _owner = 'wincert@certification.invalid';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Dio ownerDio;
  late InstitutionVerificationRepository ownerRepo;
  late String institutionId;
  late String strangerId;

  setUpAll(() async {
    final login = await http.post(
      Uri.parse('$_api/auth/login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'email': _owner, 'password': _password}),
    );
    expect(
      login.statusCode,
      inInclusiveRange(200, 299),
      reason: 'the phone must reach the isolated stack through the adb reverse '
          'tunnel, and the fixture must be seeded: ${login.body}',
    );
    final decoded = jsonDecode(login.body) as Map<String, dynamic>;
    final data = (decoded['data'] ?? decoded) as Map<String, dynamic>;
    final token = (data['accessToken'] ?? data['token']) as String;

    ownerDio = Dio(BaseOptions(
      baseUrl: _api,
      headers: {'authorization': 'Bearer $token'},
    ));
    ownerRepo = InstitutionVerificationRepository(ownerDio);

    final mine = await ownerDio.get<Map<String, dynamic>>('/institutions/me');
    final body = (mine.data?['data'] ?? mine.data) as Map<String, dynamic>;
    final membership = body['membership'] as Map<String, dynamic>?;
    expect(membership, isNotNull, reason: 'fixture owner must hold a membership');
    institutionId = (membership!['institution'] as Map)['id'].toString();

    strangerId = 'inst_not_mine_${DateTime.now().millisecondsSinceEpoch}';

    // PRECONDITION, ASSERTED RATHER THAN ASSUMED.
    //
    // This lane DRIVES the journey: it starts a verification and submits
    // evidence. Run against a fixture a previous run already advanced, the
    // lifecycle refuses the submission -- correctly -- and the refusal would
    // be reported as a product defect somewhere in the middle of the owner
    // group. The seeder resets the fixture; this proves it did, before
    // anything depends on it.
    final pre = await ownerRepo.standing(institutionId);
    expect(
      pre.existence.state,
      anyOf(ExistenceState.notStarted, ExistenceState.needsInfo),
      reason: 'the native-lane fixture is stale: existence is already '
          '${pre.existence.state}. Re-seed before certifying:\n'
          '  node scripts/identity-certification/'
          'institution-verification-journey-proof.mjs',
    );
  });

  group('the platform reaches the contract', () {
    test('POSITIVE CONTROL — Android can talk to the stack at all', () async {
      // Without this every refusal below could pass because nothing connected.
      final res = await ownerDio.get<Map<String, dynamic>>(
        '/institutions/$institutionId/verification',
        options: Options(validateStatus: (_) => true),
      );
      expect(res.statusCode, 200, reason: 'the owner must be able to read their own standing');
    });

    test('THE OWNER STANDING PARSES ON ARM64', () async {
      final standing = await ownerRepo.standing(institutionId);

      // The envelope defect that blanked this screen on web would blank it here
      // too; nothing about it is platform-specific, and that is the point of
      // asserting it again rather than inheriting the web result.
      expect(standing.institutionId, institutionId);
      expect(standing.existence.state, isNot(ExistenceState.unknown),
          reason: 'an unwrapped envelope shows every field as unknown');
      expect(standing.authority.state, isNot(AuthorityState.unknown));
    });
  });

  group('the authority gates hold from the phone', () {
    test('AN ACCOUNT WITHOUT STANDING IS REFUSED, with the reason intact', () async {
      Object? raised;
      try {
        await ownerRepo.standing(strangerId);
      } catch (e) {
        raised = e;
      }
      expect(raised, isA<InstitutionVerificationException>());
      final refusal = raised! as InstitutionVerificationException;
      expect(refusal.message.trim(), isNotEmpty);
      // The server's own words, not the offline sentence.
      expect(refusal.message, isNot(contains('could not reach verification')));
      expect(refusal.code, isNotNull);
    });

    test('SUBMITTING TO SOMEBODY ELSE IS REFUSED', () async {
      Object? raised;
      try {
        await ownerRepo.submitExistence(
          strangerId,
          const [SuppliedEvidence(reference: 'Companies House 09876543')],
        );
      } catch (e) {
        raised = e;
      }
      expect(raised, isA<InstitutionVerificationException>());
    });

    test('THE REVIEWER QUEUE IS NOT READABLE WITHOUT THE PERMISSION', () async {
      final res = await ownerDio.get<Map<String, dynamic>>(
        '/institutions/admin/verification/queue',
        options: Options(validateStatus: (_) => true),
      );
      // This owner holds no VERIFICATION_READ grant.
      expect(res.statusCode, anyOf(401, 403));
    });
  });

  group('the owner journey works from the phone', () {
    test('START IS IDEMPOTENT AND RECORDS THE CATEGORY', () async {
      final first = await ownerRepo.start(institutionId, 'NONPROFIT_COMMUNITY');
      final again = await ownerRepo.start(institutionId, 'GOVERNMENT_CIVIC');

      // Pressing start twice is a person checking, not a person discarding —
      // and a category already recorded is never moved.
      expect(first.category, isNotNull);
      expect(again.category, first.category);
    });

    test('EVIDENCE SUBMITTED FROM ANDROID MOVES THE PROOF', () async {
      final after = await ownerRepo.submitExistence(
        institutionId,
        const [SuppliedEvidence(reference: 'Charity Commission 1122334')],
      );
      expect(
        after.existence.state,
        anyOf(ExistenceState.submitted, ExistenceState.manualReview),
        reason: 'a submission from the phone must reach a review state',
      );
    });

    test('EVIDENCE FROM ANDROID NAMES NO SUBMITTER', () {
      const evidence = SuppliedEvidence(reference: 'Charity Commission 1122334');
      expect(evidence.toJson().containsKey('submittedByUserId'), isFalse);
    });
  });

  group('notification destinations resolve on Android', () {
    test('EVERY SUBJECT NOTICE OPENS THAT INSTITUTION', () {
      for (final type in const [
        'INSTITUTION_VERIFICATION_NEEDS_INFO',
        'INSTITUTION_VERIFICATION_CONFIRMED',
        'INSTITUTION_VERIFICATION_REJECTED',
        'INSTITUTION_AUTHORITY_GRANTED',
        'INSTITUTION_AUTHORITY_REVOKED',
      ]) {
        expect(
          institutionVerificationDestination(type, institutionId),
          '/institution/$institutionId/verification',
        );
      }
    });

    test('THE QUEUE NOTICE DOES NOT OPEN AN INSTITUTION', () {
      final d = institutionVerificationDestination(
        'INSTITUTION_VERIFICATION_SUBMITTED',
        institutionId,
      );
      expect(d, '/admin/integrity/institution-verification');
      expect(d, isNot(contains(institutionId)));
    });

    test('A NOTICE WITH NO INSTITUTION IS INERT, not somebody else', () {
      expect(
        institutionVerificationDestination('INSTITUTION_AUTHORITY_REVOKED', null),
        isNull,
      );
    });
  });

  group('the screen renders on a real phone', () {
    testWidgets('MOBILE LAYOUT DOES NOT OVERFLOW', (tester) async {
      // A narrow viewport is where this fails if it fails at all, and a phone
      // is the common case for somebody completing verification, not the edge.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            institutionVerificationStandingProvider(institutionId).overrideWith(
              (ref) async => InstitutionVerificationStanding.fromJson({
                'institutionId': institutionId,
                'category': 'NONPROFIT_COMMUNITY',
                'requiresManualReview': true,
                'existence': {
                  'state': 'NEEDS_INFO',
                  'available': ['SUBMITTED'],
                  'infoRequested':
                      'Please send the registration certificate showing the current address.',
                  'acceptsEvidence': true,
                  'confidence': null,
                  'accepted': ['A registration reference', 'A tax-exemption reference'],
                  'requirementNotEnumerated': false,
                },
                'authority': {
                  'state': 'LEGACY_UNVERIFIED',
                  'available': ['SUBMITTED'],
                  'infoRequested': null,
                  'acceptsEvidence': true,
                  'evidenceKind': null,
                  'menu': ['APPOINTMENT_LETTER', 'EXISTING_HOLDER_APPROVAL'],
                },
                'migration': {
                  'reason': 'IN_WINDOW',
                  'deadlineAt': '2027-01-08T09:00:00.000Z',
                  'daysRemaining': 110,
                  'authorityGovernanceBlocked': true,
                  'institutionVoiceBlocked': false,
                },
              }),
            ),
          ],
          child: MaterialApp(
            // The real tree: MemberShell wraps every routed screen in a
            // Scaffold, and that is what supplies the Material ancestor
            // TextField/ListTile require. Mounting bare under `home:`
            // would be a tree the app never builds.
            home: Scaffold(
              body: InstitutionVerificationScreen(
                institutionId: institutionId,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // No RenderFlex overflow, on a real device, at a real phone size.
      expect(tester.takeException(), isNull);
    });

    testWidgets('THE THREE PROOFS ARE NOT COLLAPSED, on a phone', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            institutionVerificationStandingProvider(institutionId).overrideWith(
              (ref) async => InstitutionVerificationStanding.fromJson({
                'institutionId': institutionId,
                'existence': {
                  'state': 'CONFIRMED',
                  'available': <String>[],
                  'acceptsEvidence': false,
                  'confidence': 'DOMAIN_ONLY',
                },
                'authority': {
                  'state': 'LEGACY_UNVERIFIED',
                  'available': ['SUBMITTED'],
                  'acceptsEvidence': true,
                  'menu': <String>[],
                },
                'migration': {'reason': 'NOT_ANCHORED'},
              }),
            ),
          ],
          child: MaterialApp(
            // The real tree: MemberShell wraps every routed screen in a
            // Scaffold, and that is what supplies the Material ancestor
            // TextField/ListTile require. Mounting bare under `home:`
            // would be a tree the app never builds.
            home: Scaffold(
              body: InstitutionVerificationScreen(
                institutionId: institutionId,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Two separate questions, answered separately, and the third named.
      expect(find.text('Does this institution exist?'), findsOneWidget);
      expect(find.text('May you speak for it?'), findsOneWidget);
      expect(
        find.textContaining('identity verification is a third'),
        findsOneWidget,
      );

      // CONFIRMED at DOMAIN_ONLY reads as what was checked, not a shortfall.
      expect(find.text('Confirmed by domain'), findsOneWidget);
      // LEGACY_UNVERIFIED is never rendered as verified.
      expect(find.text('Carried over, not yet evidenced'), findsOneWidget);
    });

    testWidgets('THE DEADLINE SHOWS A DATE, never a relative phrase', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            institutionVerificationStandingProvider(institutionId).overrideWith(
              (ref) async => InstitutionVerificationStanding.fromJson({
                'institutionId': institutionId,
                'existence': {'state': 'CONFIRMED', 'available': <String>[], 'acceptsEvidence': false},
                'authority': {'state': 'LEGACY_UNVERIFIED', 'available': <String>[], 'acceptsEvidence': false, 'menu': <String>[]},
                'migration': {
                  'reason': 'IN_WINDOW',
                  'deadlineAt': '2027-01-08T09:00:00.000Z',
                  'daysRemaining': 110,
                  'authorityGovernanceBlocked': true,
                  'institutionVoiceBlocked': false,
                },
              }),
            ),
          ],
          child: MaterialApp(
            // The real tree: MemberShell wraps every routed screen in a
            // Scaffold, and that is what supplies the Material ancestor
            // TextField/ListTile require. Mounting bare under `home:`
            // would be a tree the app never builds.
            home: Scaffold(
              body: InstitutionVerificationScreen(
                institutionId: institutionId,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('Please complete this by'), findsOneWidget);
      // §6 forbids relative phrasing; it also drifts once a screen is left open.
      expect(find.textContaining('days left'), findsNothing);
      expect(find.textContaining('110 days'), findsNothing);
      // Non-punitive, and the continuity promise is on the same card.
      expect(find.textContaining('Nothing is deleted'), findsOneWidget);
    });

    testWidgets('A DEADLINE THAT IS NOT RUNNING IS NOT SHOWN', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            institutionVerificationStandingProvider(institutionId).overrideWith(
              (ref) async => InstitutionVerificationStanding.fromJson({
                'institutionId': institutionId,
                'existence': {'state': 'NOT_STARTED', 'available': <String>[], 'acceptsEvidence': false},
                'authority': {'state': 'NOT_STARTED', 'available': <String>[], 'acceptsEvidence': false, 'menu': <String>[]},
                'migration': {'reason': 'NOT_ANCHORED', 'deadlineAt': null},
              }),
            ),
          ],
          child: MaterialApp(
            // The real tree: MemberShell wraps every routed screen in a
            // Scaffold, and that is what supplies the Material ancestor
            // TextField/ListTile require. Mounting bare under `home:`
            // would be a tree the app never builds.
            home: Scaffold(
              body: InstitutionVerificationScreen(
                institutionId: institutionId,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // No notice delivered, so no countdown shown to somebody never told.
      expect(find.textContaining('Please complete this by'), findsNothing);
      expect(find.text('Not started'), findsWidgets);
    });

    testWidgets('A LOAD FAILURE OFFERS RETRY RATHER THAN A DEAD SCREEN', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            institutionVerificationStandingProvider(institutionId).overrideWith(
              (ref) async => throw const InstitutionVerificationException(
                'That step needs supporting evidence, and none has been supplied.',
                code: 'VERIFICATION_EVIDENCE_REQUIRED',
              ),
            ),
          ],
          child: MaterialApp(
            // The real tree: MemberShell wraps every routed screen in a
            // Scaffold, and that is what supplies the Material ancestor
            // TextField/ListTile require. Mounting bare under `home:`
            // would be a tree the app never builds.
            home: Scaffold(
              body: InstitutionVerificationScreen(
                institutionId: institutionId,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The server's own words survive to the phone, and recovery is offered.
      expect(
        find.textContaining('needs supporting evidence'),
        findsOneWidget,
        reason: 'a real reason must not be replaced by a generic sentence',
      );
      expect(find.textContaining('Retry'), findsWidgets);
    });
  });
}
